public with sharing class stoThreadReadState {
    @AuraEnabled
    public static void markThreadRead(Id threadId, Id latestDisplayedMessageId) {
        List<Thread__c> threads = [
            SELECT Id, CRM_Account__c, CRM_Thread_Type__c
            FROM Thread__c
            WHERE Id = :threadId AND CRM_Thread_Type__c IN ('STO', 'STB', 'BTO', 'CHAT')
            WITH USER_MODE
        ];
        if (threads.isEmpty()) {
            throw new AuraHandledException('Du har ikke tilgang til samtalen.');
        }
        stoPersonContext.resolveAccountId(threads[0].CRM_Account__c);
        if (threads[0].CRM_Thread_Type__c == 'CHAT') {
            new LegacyReadFlags().markRead(threadId);
            return;
        }
        List<Message__c> messages = [
            SELECT Id, CreatedDate
            FROM Message__c
            WHERE Id = :latestDisplayedMessageId AND CRM_Thread__c = :threadId AND CRM_Type__c IN ('Message', 'Info')
            WITH USER_MODE
        ];
        if (messages.isEmpty()) {
            throw new AuraHandledException('Meldingen finnes ikke i samtalen.');
        }
        Id readerId = UserInfo.getUserId();
        String key = String.valueOf(readerId) + ':' + String.valueOf(threadId);
        // Lock only this reader's receipt, never the shared thread.
        List<STO_Thread_Read_State__c> receipts = [
            SELECT Id, Last_Read_Created__c, Last_Read_Message_Id__c
            FROM STO_Thread_Read_State__c
            WHERE Reader_Thread_Key__c = :key AND Reader__c = :readerId
            WITH SYSTEM_MODE
            FOR UPDATE
        ];
        Message__c displayed = messages[0];
        if (!receipts.isEmpty() && !isAfter(displayed, receipts[0])) {
            new LegacyReadFlags().markRead(threadId);
            return;
        }
        STO_Thread_Read_State__c receipt = receipts.isEmpty()
            ? new STO_Thread_Read_State__c(Reader__c = readerId, Thread__c = threadId, Reader_Thread_Key__c = key)
            : receipts[0];
        receipt.Last_Read_Created__c = displayed.CreatedDate;
        receipt.Last_Read_Message_Id__c = displayed.Id;
        if (receipts.isEmpty()) {
            // A concurrent first insert must not overwrite a newer cursor via upsert.
            // The unique external ID rejects the loser; the client retries after re-reading.
            insert as system receipt;
        } else {
            update as system receipt;
        }
        new LegacyReadFlags().markRead(threadId);
    }

    // Reading a shared transcript does not confer edit access to its messages.
    // Only this reporting update is elevated, after the outer class verifies thread/account access.
    private without sharing class LegacyReadFlags {
        public void markRead(Id authorizedThreadId) {
            List<Message__c> messages = [
                SELECT Id, CRM_Read__c, CRM_Read_Datetime__c
                FROM Message__c
                WHERE CRM_Thread__c = :authorizedThreadId AND CRM_Read__c = FALSE
                WITH SYSTEM_MODE
            ];
            Datetime readAt = Datetime.now();
            for (Message__c message : messages) {
                message.CRM_Read__c = true;
                message.CRM_Read_Datetime__c = readAt;
            }
            if (!messages.isEmpty())
                update as system messages;
        }
    }

    public static Boolean isAfter(Message__c message, STO_Thread_Read_State__c receipt) {
        return receipt == null ||
            receipt.Last_Read_Created__c == null ||
            message.CreatedDate > receipt.Last_Read_Created__c ||
            (message.CreatedDate == receipt.Last_Read_Created__c &&
            String.valueOf(message.Id).compareTo(receipt.Last_Read_Message_Id__c) > 0);
    }

    public static Map<Id, Decimal> unread(List<Thread__c> threads, Id viewerContactId) {
        Map<Id, Thread__c> byId = new Map<Id, Thread__c>(threads);
        Set<Id> threadIds = byId.keySet();
        Map<Id, STO_Thread_Read_State__c> receipts = new Map<Id, STO_Thread_Read_State__c>();
        Id readerId = UserInfo.getUserId();
        for (STO_Thread_Read_State__c receipt : [
            SELECT Thread__c, Last_Read_Created__c, Last_Read_Message_Id__c
            FROM STO_Thread_Read_State__c
            WHERE Reader__c = :readerId AND Thread__c IN :threadIds
            WITH SYSTEM_MODE
        ]) {
            receipts.put(receipt.Thread__c, receipt);
        }
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (Thread__c candidate : [
            SELECT
                Id,
                (
                    SELECT Id, CreatedDate
                    FROM Messages__r
                    WHERE
                        CRM_Type__c IN ('Message', 'Info')
                        AND (CRM_From_Contact__c = NULL
                        OR CRM_From_Contact__c != :viewerContactId)
                    ORDER BY CreatedDate DESC, Id DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE Id IN :threadIds
            WITH USER_MODE
        ]) {
            Thread__c thread = byId.get(candidate.Id);
            Decimal unread = 0;
            if (thread.CRM_Thread_Type__c == 'CHAT') {
                unread = thread.CRM_Number_of_unread_Messages__c;
            } else if (!candidate.Messages__r.isEmpty()) {
                Message__c latest = candidate.Messages__r[0];
                STO_Thread_Read_State__c receipt = receipts.get(thread.Id);
                if (receipt != null) {
                    unread = isAfter(latest, receipt) ? 1 : 0;
                } else {
                    // Global legacy flags identify no reader, including the thread owner.
                    unread = 1;
                }
            }
            result.put(thread.Id, unread);
        }
        return result;
    }
}

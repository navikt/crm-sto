public with sharing class stoInboxHelper {
    //TODO: Use custom labels

    @AuraEnabled(cacheable=true)
    public static List<thread> getThreads() {
        List<thread> inboxlist = new List<thread>();
        List<Thread__c> threadList = [
            SELECT
                Id,
                Name,
                LastModifiedDate,
                CRM_Number_of_unread_Messages__c,
                CRM_Latest_Message_Datetime__c,
                CRM_Closed_Date__c,
                STO_ExternalName__c,
                CRM_Is_Closed__C
            FROM Thread__c
            WHERE CRM_Number_of_unread_Messages__c = 0 AND CRM_Is_Closed__C = TRUE
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for (Thread__c t : threadList) {
            inboxlist.add(new thread(t));
        }
        List<Conversation_Note__c> noteList = [
            SELECT Id, Name, LastModifiedDate, CRM_Date_Time_Registered__c, CRM_Is_Read__c, STO_External_Name__c
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = TRUE AND CRM_Created_By_Ident__c != NULL
            ORDER BY CRM_Date_Time_Registered__c DESC
        ];
        //Do we need to handle
        for (Conversation_Note__c t : noteList) {
            inboxlist.add(new thread(t));
        }
        return inboxlist;
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreads() {
        List<thread> inboxlist = new List<thread>();
        List<Thread__c> threadList = [
            SELECT
                Id,
                Name,
                LastModifiedDate,
                CRM_Number_of_unread_Messages__c,
                CRM_Latest_Message_Datetime__c,
                CRM_Closed_Date__c,
                STO_ExternalName__c,
                CRM_Is_Closed__C
            FROM Thread__c
            WHERE CRM_Number_of_unread_Messages__c > 0 OR CRM_Is_Closed__c = FALSE
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for (Thread__c t : threadList) {
            inboxlist.add(new thread(t));
        }
        List<Conversation_Note__c> noteList = [
            SELECT
                Id,
                Name,
                LastModifiedDate,
                CRM_Date_Time_Registered__c,
                CRM_Is_Read__c,
                STO_External_Name__c,
                CRM_Henvendelse_BehandlingsId__c
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = FALSE AND CRM_Created_By_Ident__c != NULL
            ORDER BY CRM_Date_Time_Registered__c DESC
        ];
        for (Conversation_Note__c t : noteList) {
            inboxlist.add(new thread(t));
        }
        return inboxlist;
    }

    public class thread {
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Datetime lastModifiedDate;
        @AuraEnabled
        public Datetime closeDate;
        @AuraEnabled
        public Decimal numberOfUnreadMessages;
        @AuraEnabled
        public Datetime latestMessageDate;
        @AuraEnabled
        public String objectName;
        @AuraEnabled
        public String status;

        public thread(Thread__c t) {
            this.name = t.STO_ExternalName__c;
            this.recordId = t.Id;
            this.lastModifiedDate = t.LastModifiedDate;
            this.closeDate = t.CRM_Closed_Date__c;
            this.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c;
            this.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            this.objectName = 'skriv-til-oss';
            this.status = (t.CRM_Is_Closed__C) ? 'Lukket' : 'Åpen';
        }

        public thread(Conversation_Note__c convNote) {
            this.name = convNote.STO_External_Name__c;
            this.recordId = convNote.Id;
            this.lastModifiedDate = convNote.LastModifiedDate;
            this.closeDate = convNote.CRM_Date_Time_Registered__c;
            this.numberOfUnreadMessages = convNote.CRM_Is_Read__c ? 0 : 1;
            this.latestMessageDate = convNote.CRM_Date_Time_Registered__c;
            this.objectName = 'samtalereferat';
            this.status = 'Lukket';
        }
    }

    @AuraEnabled(cacheable=true)
    public static message getLatestMessage(Id threadId) {
        message returntext = new message();
        String objectName = threadId.getSobjectType().getDescribe().getName();
        if (objectName == 'Thread__c') {
            objectName = 'skriv-til-oss';
            Message__c messageList = [
                SELECT Id, CRM_Message_Text__c, CRM_From_Contact__c
                FROM Message__c
                WHERE CRM_Thread__c = :threadId AND CRM_Type__c = 'Message'
                ORDER BY CRM_Sent_Datetime_Formula__c DESC
                LIMIT 1
            ];
            returntext.fromContact = messageList.CRM_From_Contact__c;
            returntext.messageText = messageList.CRM_Message_Text__c;
            returntext.recordId = messageList.Id;
        }
        if (objectName == 'Conversation_Note__c') {
            objectName = 'samtalereferat';
            Conversation_Note__c cn = [
                SELECT Id, Name, CRM_Conversation_Note__c
                FROM Conversation_Note__c
                WHERE Id = :threadId
                LIMIT 1
            ];
            returntext.fromContact = 'NAV';
            returntext.messageText = cn.CRM_Conversation_Note__c;
            returntext.recordId = cn.Id;
        }
        return returntext;
    }

    @AuraEnabled
    public static List<thread> getNotesByBehandlingskjedeId(String kjedeId) {
        List<thread> notes = new List<thread>();
        return notes;
    }

    public class message {
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String messageText;
        @AuraEnabled
        public String fromContact;
    }

    @AuraEnabled
    public static void markAsRead(Id conversationNoteId) {
        List<Conversation_Note__c> noteList = [
            SELECT Id
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = FALSE AND Id = :conversationNoteId
            LIMIT 1
        ];
        for (Conversation_Note__c cn : noteList) {
            cn.CRM_Is_Read__c = true;
            cn.CRM_Read_Date__c = DateTime.now();
        }
        update noteList;
    }
}

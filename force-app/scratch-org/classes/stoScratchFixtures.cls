public with sharing class stoScratchFixtures implements System.Callable {
    @TestVisible
    private static Integer PAGE_SIZE = 50;

    public Object call(String action, Map<String, Object> arguments) {
        if (!stoScratchSupport.isEnabled()) {
            throw new AuraHandledException('Scratch fixtures are not enabled for this user.');
        }
        Map<String, List<String>> family = family();
        Set<String> identities = new Set<String>(family.keySet());
        for (List<String> children : family.values()) {
            identities.addAll(children);
        }
        Id ownAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
        List<Account> actors = [
            SELECT Id, INT_PersonIdent__c
            FROM Account
            WHERE Id = :ownAccountId AND IsPersonAccount = TRUE AND INT_PersonIdent__c IN :identities
        ];
        if (actors.isEmpty()) {
            throw new AuraHandledException('Scratch fixtures are restricted to the five synthetic community users.');
        }
        Account actor = actors[0];
        if (action == 'inbox') {
            Id accountId = (Id) arguments.get('accountId');
            if (accountId == null) {
                accountId = actor.Id;
            }
            if (accountId != actor.Id) {
                Set<Id> allowed = new Set<Id>();
                for (stoPersonContext.PersonOption child : stoPersonContext.getRepresentableChildren()) {
                    allowed.add(child.value);
                }
                if (!allowed.contains(accountId)) {
                    throw new AuraHandledException('You cannot view this fixture inbox.');
                }
            }
            return inbox(accountId, (Id) arguments.get('threadId'), (Id) arguments.get('noteId'));
        }
        if ((String) arguments.get('parentIdent') != actor.INT_PersonIdent__c) {
            throw new AuraHandledException('The fixture identity must match the authenticated user.');
        }
        List<String> children = family.get(actor.INT_PersonIdent__c);
        if (children == null) {
            children = new List<String>();
        }
        if (action == 'barn') {
            return childrenResponse(children);
        }
        if (action == 'verifiser') {
            return response(
                new Map<String, Object>{ 'kanRepresentere' => children.contains((String) arguments.get('childIdent')) }
            );
        }
        throw new AuraHandledException('Unknown scratch fixture action: ' + action);
    }

    private static Map<String, List<String>> family() {
        StaticResource fixture = [SELECT Body FROM StaticResource WHERE Name = 'STO_Foreldreansvar_Family' LIMIT 1];
        return (Map<String, List<String>>) JSON.deserialize(fixture.Body.toString(), Map<String, List<String>>.class);
    }

    private static HttpResponse childrenResponse(List<String> children) {
        List<Object> result = new List<Object>();
        if (!children.isEmpty()) {
            HttpResponse configured = new ApiMock().initMock('POST_FORELDREANSVAR_BARN', 200, 'OK').respond();
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(configured.getBody());
            Map<String, Object> detailsByIdent = new Map<String, Object>();
            for (Object child : (List<Object>) body.get('barn')) {
                Map<String, Object> details = (Map<String, Object>) child;
                detailsByIdent.put((String) details.get('ident'), details);
            }
            for (String ident : children) {
                if (!detailsByIdent.containsKey(ident)) {
                    throw new AuraHandledException('The configured child service mock is missing a fixture child.');
                }
                result.add(detailsByIdent.get(ident));
            }
        }
        return response(new Map<String, Object>{ 'barn' => result });
    }

    private static HttpResponse response(Map<String, Object> body) {
        HttpResponse result = new HttpResponse();
        result.setStatusCode(200);
        result.setHeader('Content-Type', 'application/json');
        result.setBody(JSON.serialize(body));
        return result;
    }

    @TestVisible
    private static Map<String, Object> inbox(Id accountId, Id threadId, Id noteId) {
        Integer fetchSize = PAGE_SIZE + 1;
        String threadCursor = '';
        Datetime threadDate;
        if (threadId != null) {
            List<Thread__c> cursors = [
                SELECT CRM_Latest_Message_Datetime__c
                FROM Thread__c
                WHERE Id = :threadId AND CRM_Account__c = :accountId
            ];
            if (cursors.isEmpty()) {
                throw new AuraHandledException('Invalid fixture thread cursor.');
            }
            threadDate = cursors[0].CRM_Latest_Message_Datetime__c;
            threadCursor = threadDate == null
                ? ' AND CRM_Latest_Message_Datetime__c = NULL AND Id < :threadId'
                : ' AND (CRM_Latest_Message_Datetime__c < :threadDate OR CRM_Latest_Message_Datetime__c = NULL' +
                  ' OR (CRM_Latest_Message_Datetime__c = :threadDate AND Id < :threadId))';
        }
        List<Thread__c> threads = Database.query(
            'SELECT Id, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c,' +
                ' CRM_Closed_Date__c, STO_ExternalName__c, CRM_Is_Closed__c, CRM_Thread_Type__c, CRM_Related_Object__c,' +
                ' Name, NKS_Inbox_Title__c, NKS_Inbox_Theme__c, CRM_Theme_Group_Name__c, STO_Category__c,' +
                ' (SELECT Id, CRM_Message_Text__c, CRM_External_Message__c FROM Messages__r' +
                ' WHERE CRM_Type__c IN (\'Message\', \'Info\') ORDER BY CRM_Sent_Datetime_Formula__c DESC, Id DESC LIMIT 1)' +
                ' FROM Thread__c WHERE CRM_Account__c = :accountId AND CRM_Thread_Type__c IN (\'STO\', \'BTO\', \'STB\', \'CHAT\')' +
                threadCursor +
                ' ORDER BY CRM_Latest_Message_Datetime__c DESC NULLS LAST, Id DESC LIMIT :fetchSize'
        );
        Boolean hasMore = threads.size() > PAGE_SIZE;
        if (hasMore) {
            threads.remove(PAGE_SIZE);
        }
        List<Object> recent = new List<Object>();
        List<Object> older = new List<Object>();
        Map<Id, String> senderLabels = stoReplyContext.inboxSenderLabels(new Map<Id, Thread__c>(threads).keySet());
        for (Thread__c record : threads) {
            threadId = record.Id;
            stoInboxHelper.Thread formatted = stoInboxHelper.formatThread(record);
            if (formatted == null) {
                continue;
            }
            Map<String, Object> item = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(formatted));
            item.put('inboxSenderLabel', senderLabels.get(record.Id));
            item.put(
                'category',
                record.CRM_Thread_Type__c == 'CHAT' ? record.CRM_Theme_Group_Name__c : record.STO_Category__c
            );
            if (!record.CRM_Is_Closed__c || record.CRM_Number_of_unread_Messages__c > 0) {
                recent.add(item);
            } else {
                older.add(item);
            }
        }
        String noteCursor = '';
        Datetime noteDate;
        if (noteId != null) {
            List<Conversation_Note__c> cursors = [
                SELECT CRM_Date_Time_Registered__c
                FROM Conversation_Note__c
                WHERE Id = :noteId AND CRM_Account__c = :accountId
            ];
            if (cursors.isEmpty()) {
                throw new AuraHandledException('Invalid fixture note cursor.');
            }
            noteDate = cursors[0].CRM_Date_Time_Registered__c;
            noteCursor = noteDate == null
                ? ' AND CRM_Date_Time_Registered__c = NULL AND Id < :noteId'
                : ' AND (CRM_Date_Time_Registered__c < :noteDate OR CRM_Date_Time_Registered__c = NULL' +
                  ' OR (CRM_Date_Time_Registered__c = :noteDate AND Id < :noteId))';
        }
        List<Conversation_Note__c> notes = Database.query(
            'SELECT Id, LastModifiedDate, CRM_Date_Time_Registered__c, STO_External_Name__c,' +
                ' CRM_Conversation_Note__c, Name, CRM_Is_Read__c, CRM_Theme_Group_Name__c' +
                ' FROM Conversation_Note__c WHERE CRM_Account__c = :accountId AND CRM_Created_By_Ident__c != NULL' +
                noteCursor +
                ' ORDER BY CRM_Date_Time_Registered__c DESC NULLS LAST, Id DESC LIMIT :fetchSize'
        );
        if (notes.size() > PAGE_SIZE) {
            hasMore = true;
            notes.remove(PAGE_SIZE);
        }
        for (Conversation_Note__c record : notes) {
            noteId = record.Id;
            Map<String, Object> item = (Map<String, Object>) JSON.deserializeUntyped(
                JSON.serialize(stoInboxHelper.formatConversationNote(record, record.CRM_Is_Read__c))
            );
            item.put('category', record.CRM_Theme_Group_Name__c);
            if (record.CRM_Is_Read__c) {
                older.add(item);
            } else {
                recent.add(item);
            }
        }
        return new Map<String, Object>{
            'recent' => recent,
            'older' => older,
            'beforeThreadId' => threadId,
            'beforeNoteId' => noteId,
            'hasMore' => hasMore
        };
    }
}

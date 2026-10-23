@IsTest
private class stoThreadReadStateTest {
    @TestSetup
    static void setup() {
        // External cache invalidation queries once per message when its integration user is absent.
        // Isolate the inbox scale fixture from that unrelated integration handler.
        MyTriggers.disable(MessageCacheHandler.class);
        List<Thread__c> threads = new List<Thread__c>();
        for (Integer i = 0; i < 121; i++) {
            threads.add(
                new Thread__c(
                    CRM_Thread_Type__c = 'STO',
                    CRM_Closed_Date__c = Math.mod(i, 2) == 0 ? Date.today() : null
                )
            );
        }
        insert threads;
        List<Message__c> messages = new List<Message__c>();
        for (Thread__c thread : threads) {
            for (Integer i = 0; i < 8; i++) {
                messages.add(
                    new Message__c(
                        CRM_Thread__c = thread.Id,
                        CRM_Type__c = Math.mod(i, 2) == 0 ? 'Message' : 'Info',
                        CRM_Message_Text__c = 'Incoming message ' + i,
                        CRM_Read__c = false
                    )
                );
            }
        }
        insert messages;
    }

    @IsTest
    static void bulkPagesHaveBoundedQueriesAndRows() {
        Test.startTest();
        Integer queries = Limits.getQueries();
        Integer rows = Limits.getQueryRows();
        stoInboxHelper.InboxPage first = stoInboxHelper.getInboxPage(null, null, null);
        Assert.isTrue(Limits.getQueries() - queries <= 10, 'No per-thread queries');
        Assert.isTrue(Limits.getQueryRows() - rows < 400, 'Do not load complete message histories');
        Assert.areEqual(50, first.recent.size() + first.older.size());
        Assert.isTrue(first.hasMore);
        Set<Id> ids = new Set<Id>();
        for (stoInboxHelper.Thread item : first.recent) {
            ids.add(item.recordId);
            Assert.areEqual(1, item.numberOfUnreadMessages, 'Unread is an existence indicator, not a global count');
        }
        stoInboxHelper.InboxPage second = stoInboxHelper.getNextInboxPage(
            null,
            first.beforeThreadId,
            first.beforeNoteId
        );
        Assert.isTrue(second.hasMore);
        for (stoInboxHelper.Thread item : second.recent) {
            Assert.isTrue(ids.add(item.recordId), 'No duplicate across equal-date cursor boundaries');
        }
        stoInboxHelper.InboxPage third = stoInboxHelper.getInboxPage(null, second.beforeThreadId, second.beforeNoteId);
        Assert.isFalse(third.hasMore);
        for (stoInboxHelper.Thread item : third.recent) {
            Assert.isTrue(ids.add(item.recordId));
        }
        Assert.areEqual(121, ids.size(), 'Pagination must expose every thread');
        Test.stopTest();
    }

    @IsTest
    static void cursorOnlyAdvancesAndClosedThreadMovesToHistory() {
        Thread__c thread = [
            SELECT Id
            FROM Thread__c
            WHERE CRM_Closed_Date__c != NULL
            ORDER BY CRM_Latest_Message_Datetime__c DESC, Id DESC
            LIMIT 1
        ];
        List<Message__c> messages = [
            SELECT Id, CreatedDate
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
            ORDER BY CreatedDate DESC, Id DESC
        ];
        Datetime sameTime = Datetime.now().addDays(-1);
        for (Message__c message : messages)
            Test.setCreatedDate(message.Id, sameTime);
        messages = [SELECT Id, CreatedDate FROM Message__c WHERE CRM_Thread__c = :thread.Id ORDER BY Id DESC];
        Test.startTest();
        stoThreadReadState.markThreadRead(thread.Id, messages[0].Id);
        Integer writes = Limits.getDmlStatements();
        stoThreadReadState.markThreadRead(thread.Id, messages[0].Id);
        stoThreadReadState.markThreadRead(thread.Id, messages[1].Id);
        Assert.areEqual(writes, Limits.getDmlStatements(), 'Repeated or older positions must not write');
        STO_Thread_Read_State__c receipt = [
            SELECT Last_Read_Message_Id__c, Reader__c, Reader_Thread_Key__c
            FROM STO_Thread_Read_State__c
            WHERE Thread__c = :thread.Id
            WITH SYSTEM_MODE
        ];
        Assert.areEqual(messages[0].Id, receipt.Last_Read_Message_Id__c);
        Assert.areEqual(UserInfo.getUserId(), receipt.Reader__c);
        Assert.areEqual(UserInfo.getUserId() + ':' + thread.Id, receipt.Reader_Thread_Key__c);
        List<Thread__c> scope = [
            SELECT Id, CRM_Contact__c, CRM_Thread_Type__c, CRM_Number_of_unread_Messages__c
            FROM Thread__c
            WHERE Id = :thread.Id
        ];
        Assert.areEqual(0, stoThreadReadState.unread(scope, null).get(thread.Id));
        stoInboxHelper.InboxPage page = stoInboxHelper.getInboxPage(null, null, null);
        Set<Id> historyIds = new Set<Id>();
        for (stoInboxHelper.Thread item : page.older)
            historyIds.add(item.recordId);
        Assert.isTrue(historyIds.contains(thread.Id), 'A closed thread read by this viewer belongs in history');
        insert new Message__c(CRM_Thread__c = thread.Id, CRM_Type__c = 'Info', CRM_Message_Text__c = 'New incoming');
        Assert.areEqual(1, stoThreadReadState.unread(scope, null).get(thread.Id), 'New Info must be unread');
        Test.stopTest();
    }

    @IsTest
    static void ownMessagesDoNotHideAnEarlierUnreadIncomingMessage() {
        Contact sender = new Contact(LastName = 'Reader');
        insert sender;
        Thread__c ownThread = new Thread__c(CRM_Thread_Type__c = 'STO');
        insert ownThread;
        insert new Message__c(
            CRM_Thread__c = ownThread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Own message',
            CRM_From_Contact__c = sender.Id
        );
        List<Thread__c> scope = [
            SELECT Id, CRM_Contact__c, CRM_Thread_Type__c, CRM_Number_of_unread_Messages__c
            FROM Thread__c
            WHERE Id = :ownThread.Id
        ];
        Test.startTest();
        Assert.areEqual(0, stoThreadReadState.unread(scope, sender.Id).get(ownThread.Id));
        insert new Message__c(CRM_Thread__c = ownThread.Id, CRM_Type__c = 'Info', CRM_Message_Text__c = 'Incoming');
        insert new Message__c(
            CRM_Thread__c = ownThread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Own newer reply',
            CRM_From_Contact__c = sender.Id
        );
        Assert.areEqual(1, stoThreadReadState.unread(scope, sender.Id).get(ownThread.Id));
        Test.stopTest();
    }

    @IsTest
    static void rejectsMismatchedMessageAndUnauthorizedAccount() {
        List<Thread__c> threads = [SELECT Id FROM Thread__c LIMIT 2];
        Id messageId = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :threads[0].Id LIMIT 1].Id;
        Account unrelated = new Account(Name = 'Unrelated');
        insert unrelated;
        Thread__c denied = new Thread__c(CRM_Thread_Type__c = 'STO', CRM_Account__c = unrelated.Id);
        insert denied;
        Test.startTest();
        for (Id threadId : new List<Id>{ threads[1].Id, denied.Id, null }) {
            try {
                stoThreadReadState.markThreadRead(threadId, messageId);
                Assert.fail('The operation must be denied');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM STO_Thread_Read_State__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void datePositionPrecedesIdTiebreak() {
        Message__c message = [SELECT Id, CreatedDate FROM Message__c LIMIT 1];
        Assert.isFalse(
            stoThreadReadState.isAfter(
                message,
                new STO_Thread_Read_State__c(
                    Last_Read_Created__c = message.CreatedDate.addSeconds(1),
                    Last_Read_Message_Id__c = message.Id
                )
            )
        );
        Assert.isTrue(
            stoThreadReadState.isAfter(
                message,
                new STO_Thread_Read_State__c(
                    Last_Read_Created__c = message.CreatedDate.addSeconds(-1),
                    Last_Read_Message_Id__c = message.Id
                )
            )
        );
    }

    @IsTest
    static void conversationNotesRemainGloballyReadAndPaginateIndependently() {
        List<Conversation_Note__c> notes = new List<Conversation_Note__c>();
        for (Integer i = 0; i < 75; i++) {
            notes.add(
                new Conversation_Note__c(
                    CRM_Is_Read__c = Math.mod(i, 2) == 0,
                    CRM_Created_By_Ident__c = 'A123456',
                    CRM_Conversation_Note__c = 'Note ' + i
                )
            );
        }
        insert notes;
        Test.startTest();
        stoInboxHelper.InboxPage first = stoInboxHelper.getInboxPage(null, null, null);
        stoInboxHelper.InboxPage second = stoInboxHelper.getNextInboxPage(
            null,
            first.beforeThreadId,
            first.beforeNoteId
        );
        Set<Id> noteIds = new Set<Id>();
        for (stoInboxHelper.InboxPage page : new List<stoInboxHelper.InboxPage>{ first, second }) {
            for (stoInboxHelper.Thread item : page.recent) {
                if (item.objectName == 'samtalereferat') {
                    Assert.isTrue(noteIds.add(item.recordId));
                    Assert.areEqual(1, item.numberOfUnreadMessages);
                }
            }
            for (stoInboxHelper.Thread item : page.older) {
                if (item.objectName == 'samtalereferat') {
                    Assert.isTrue(noteIds.add(item.recordId));
                    Assert.areEqual(0, item.numberOfUnreadMessages);
                }
            }
        }
        Assert.areEqual(75, noteIds.size());
        Test.stopTest();
    }

    @IsTest
    static void chatKeepsGlobalUnreadStateWithoutPersonalReceipts() {
        Thread__c chat = new Thread__c(CRM_Thread_Type__c = 'CHAT');
        insert chat;
        Message__c message = new Message__c(
            CRM_Thread__c = chat.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Chat',
            CRM_Read__c = false
        );
        insert message;
        List<Thread__c> scope = [
            SELECT Id, CRM_Thread_Type__c, CRM_Number_of_unread_Messages__c
            FROM Thread__c
            WHERE Id = :chat.Id
        ];
        Test.startTest();
        Assert.areEqual(scope[0].CRM_Number_of_unread_Messages__c, stoThreadReadState.unread(scope, null).get(chat.Id));
        stoThreadReadState.markThreadRead(chat.Id, message.Id);
        Assert.areEqual(0, [SELECT COUNT() FROM STO_Thread_Read_State__c]);
        Test.stopTest();
    }
}

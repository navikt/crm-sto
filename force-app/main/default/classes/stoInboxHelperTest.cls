@isTest
public with sharing class stoInboxHelperTest {
    @TestSetup
    static void makeData() {
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678910'));
        STO_TestDataFactory.createRecord(
            new Person__c(Name = '12345678911', INT_Confidential__c = 'STRENGT_FORTROLIG')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Kontakt NAV', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Tema')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Spørsmål og Svar', CRM_Code__c = 'SPM_OG_SVR', CRM_Code_Set__c = 'Oppgavetyper')
        );
        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Is_Read__c = false,
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;
    }

    private static Thread__c createInboxThread(Boolean read) {
        User viewer = [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(
            new Thread__c(
                CRM_Account__c = viewer.AccountId,
                CRM_Contact__c = viewer.ContactId,
                CRM_Thread_Type__c = 'STO',
                STO_Category__c = 'Arbeid',
                NKS_Inbox_Title__c = 'Skriv til oss',
                NKS_Inbox_Theme__c = 'Arbeid'
            )
        );
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Dette er en test melding',
            CRM_Type__c = 'Message',
            CRM_Read__c = read
        );
        return thread;
    }

    @isTest
    static void getAccessibleInboxPageNotImplementedTest() {
        Test.startTest();
        try {
            stoInboxHelper.getAccessibleInboxPage(null, null, null);
            Assert.fail('The placeholder must not return a fake empty or unauthorized inbox page.');
        } catch (AuraHandledException error) {
            Assert.areEqual('Accessible inbox page backend is not implemented yet.', error.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void getNextInboxPageNotImplementedTest() {
        Test.startTest();
        try {
            stoInboxHelper.getNextInboxPage(null, null, null);
            Assert.fail('The placeholder must not return a fake next page.');
        } catch (AuraHandledException error) {
            Assert.areEqual('Next inbox page backend is not implemented yet.', error.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void getThreadsTest() {
        Id viewerAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
        Thread__c t = createInboxThread(true);
        t.CRM_Closed_Date__c = Date.today().addDays(-1);
        update t;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Account__c = viewerAccountId,
            CRM_Is_Read__c = true,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getThreads();
        Test.stopTest();

        Assert.areEqual(false, tList.isEmpty());
        Assert.areEqual(2, tList.size());
        Assert.areEqual(
            new Set<Id>{ t.Id, cn.Id },
            new Set<Id>{ tList[0].recordId, tList[1].recordId },
            'The older inbox must contain the read thread and conversation note'
        );
    }

    @isTest
    static void getRecentThreadsTest() {
        Id viewerAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
        Thread__c t = createInboxThread(false);

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Account__c = viewerAccountId,
            CRM_Is_Read__c = false,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getRecentThreads();
        Test.stopTest();

        Assert.areEqual(false, tList.isEmpty());
        Assert.areEqual(2, tList.size());
        Assert.areEqual(
            new Set<Id>{ t.Id, cn.Id },
            new Set<Id>{ tList[0].recordId, tList[1].recordId },
            'The recent inbox must contain the unread thread and conversation note'
        );
    }

    @isTest
    static void openThreadEndpointValidatesBeforeResolvingPersonTest() {
        for (String category : new List<String>{ null, 'Unknown category' }) {
            try {
                stoInboxHelper.getAccessibleOpenThreadsForPerson(category, 'STO', null);
                Assert.fail('The endpoint called by the form must validate categories itself.');
            } catch (stoHelperClass.InvalidThreadDataException expected) {
                Assert.isNotNull(expected.getMessage());
            }
        }
        try {
            stoInboxHelper.getAccessibleOpenThreadsForPerson('Arbeid', 'Unsupported type', null);
            Assert.fail('Unsupported thread types must fail before person resolution.');
        } catch (stoHelperClass.InvalidThreadDataException expected) {
            Assert.isNotNull(expected.getMessage());
        }
    }

    @isTest
    static void openThreadOrderingBreaksTimestampTiesTest() {
        Account subject = [SELECT Id, PersonContactId FROM Account WHERE CRM_Person__r.Name = '12345678910'];
        List<Thread__c> threads = new List<Thread__c>();
        for (Integer i = 0; i < 2; i++) {
            threads.add(
                new Thread__c(
                    Name = 'Skriv til oss',
                    CRM_Account__c = subject.Id,
                    CRM_Contact__c = subject.PersonContactId,
                    CRM_Thread_Type__c = 'STO',
                    STO_Category__c = 'Arbeid'
                )
            );
        }
        insert threads;
        Datetime sentAt = Datetime.newInstance(2026, 1, 1, 12, 0, 0);
        List<Message__c> messages = new List<Message__c>();
        for (Thread__c thread : threads) {
            for (Integer i = 0; i < 2; i++) {
                messages.add(
                    new Message__c(
                        CRM_Thread__c = thread.Id,
                        CRM_Message_Text__c = 'Tied message ' + i,
                        CRM_Type__c = 'Message',
                        CRM_Sent_date__c = sentAt
                    )
                );
            }
        }
        insert messages;
        List<Thread__c> expectedThreads = [
            SELECT Id, CRM_Latest_Message_Datetime__c
            FROM Thread__c
            WHERE Id IN :threads
            ORDER BY Id DESC
        ];
        Assert.areEqual(
            expectedThreads[0].CRM_Latest_Message_Datetime__c,
            expectedThreads[1].CRM_Latest_Message_Datetime__c
        );
        List<Message__c> expectedMessages = [
            SELECT Id, CRM_Thread__c
            FROM Message__c
            WHERE CRM_Thread__c IN :threads
            ORDER BY Id DESC
        ];
        Map<Id, Id> latestMessageIds = new Map<Id, Id>();
        for (Message__c message : expectedMessages) {
            if (!latestMessageIds.containsKey(message.CRM_Thread__c)) {
                latestMessageIds.put(message.CRM_Thread__c, message.Id);
            }
        }
        Test.startTest();
        List<stoInboxHelper.thread> cards = stoInboxHelper.getOpenThreadsForAccount('arbeid', 'STO', subject.Id);
        Test.stopTest();
        Assert.areEqual(2, cards.size());
        for (Integer i = 0; i < cards.size(); i++) {
            Assert.areEqual(expectedThreads[i].Id, cards[i].recordId);
            Assert.areEqual(latestMessageIds.get(cards[i].recordId), cards[i].latestmessage.recordId);
        }
    }

    @isTest
    static void markAsReadTest() {
        Conversation_Note__c cn = [SELECT Id FROM Conversation_Note__c LIMIT 1];

        Test.startTest();
        stoInboxHelper.markAsRead(cn.Id);
        Test.stopTest();

        Boolean updatedCn = [SELECT CRM_Is_Read__c FROM Conversation_Note__c WHERE Id = :cn.Id]?.CRM_Is_Read__c;
        Assert.areEqual(true, updatedCn, 'Conversation note not marked as read');
    }
}

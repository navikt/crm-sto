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
        // LiveChatTranscript chat = STO_TestDataFactory.createLiveChatTranscripts(1)[0];
        // Thread__c chatThread = new Thread__c();
        // Message__c chatMessage = new Message__c();
        // chatThread.CRM_Related_Object__c = chat.Id;
        // insert chatThread;
        // chatMessage.CRM_Thread__c = chatThread;
        // insert chatMessage;
        // Thread__c STOThread = new Thread__c();
        // Message__c STOMessage = new Message__c();
        // insert STOThread;
        // STOMessage.CRM_Thread__c = STOThread;
        // insert STOMessage;
        insert cn;
    }

    @isTest
    static void getThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Thread__c t = stoHelperClass.createThread(null, 'Arbeid', personContact.AccountId, personContact.Id);
        t.CRM_Closed_Date__c = date.today();
        update t;
        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    @isTest
    static void getRecentThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Thread__c t = stoHelperClass.createThread(null, 'Arbeid', personContact.AccountId, personContact.Id);
        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getRecentThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    // @isTest
    // static void getLatestMessageTest() {
    //     Contact personContact = [
    //         SELECT Id, AccountId
    //         FROM Contact
    //         WHERE Account.CRM_Person__r.Name = '12345678910'
    //         LIMIT 1
    //     ];
    //     Thread__c t = stoHelperClass.createThread(null, 'Arbeid', personContact.AccountId, personContact.Id);
    //     stoHelperClass.createMessage(t, 'this is a test message again', personContact.Id);
    //     Test.startTest();
    //     stoInboxHelper.message m = stoInboxHelper.getLatestMessage(t.Id);
    //     Test.stopTest();
    //     System.assertEquals('this is a test message again', m.messageText);
    // }
    // @isTest
    // static void getLatestMessageConversationNoteTest() {
    //     Conversation_Note__c cn = [SELECT Id FROM Conversation_Note__c LIMIT 1];
    //     Test.startTest();
    //     stoInboxHelper.message m = stoInboxHelper.getLatestMessage(cn.Id);
    //     Test.stopTest();
    //     System.assertEquals('this is a test message again', m.messageText);
    // }
    @isTest
    static void markAsReadTest() {
        Conversation_Note__c cn = [SELECT Id FROM Conversation_Note__c LIMIT 1];
        Test.startTest();
        stoInboxHelper.markAsRead(cn.Id);
        Test.stopTest();
        Boolean updatedcn = [SELECT CRM_Is_Read__c FROM Conversation_Note__c WHERE Id = :cn.Id]?.CRM_Is_Read__c;
        System.assertEquals(true, updatedcn, 'Conversation note not marked as read');
    }
}

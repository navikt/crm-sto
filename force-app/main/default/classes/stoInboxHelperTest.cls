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

    @isTest
    static void getThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Thread__c t = stoHelperClass.createThread(
            null,
            'Arbeid',
            personContact.AccountId,
            personContact.Id,
            true,
            'STO'
        );
        stoHelperClass.createMessage(t, 'Dette er en test melding', personContact.Id);
        t.CRM_Closed_Date__c = date.today().addDays(-1);
        update t;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Is_read__c = true,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
        System.assert(tList.size() == 2);
    }
    @isTest
    static void getRecentThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Thread__c t = stoHelperClass.createThread(
            null,
            'Arbeid',
            personContact.AccountId,
            personContact.Id,
            true,
            'STO'
        );
        Message__c m = new Message__c();
        m.CRM_Thread__c = t.Id;
        insert m;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Is_read__c = false,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getRecentThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }

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

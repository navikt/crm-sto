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

    private static Thread__c createThread() {
        Contact person = [SELECT Id, AccountId FROM Contact WHERE Account.CRM_Person__r.Name = '12345678910' LIMIT 1];
        stoInboxHelper.cachedAccountId = person.AccountId;
        Thread__c thread = new Thread__c(
            Name = 'Skriv til oss',
            CRM_Account__c = person.AccountId,
            CRM_Contact__c = person.Id,
            CRM_Thread_Type__c = 'STO',
            STO_Category__c = 'Arbeid'
        );
        insert thread;
        insert new Message__c(CRM_Thread__c = thread.Id, CRM_Message_Text__c = 'Test message', CRM_Read__c = true);
        return thread;
    }

    @isTest
    static void getThreadsTest() {
        Thread__c t = createThread();
        t.CRM_Closed_Date__c = Date.today().addDays(-1);
        update t;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Account__c = stoInboxHelper.cachedAccountId,
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
    }

    @isTest
    static void getRecentThreadsTest() {
        Thread__c t = createThread();
        Message__c m = new Message__c();
        m.CRM_Thread__c = t.Id;
        insert m;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Account__c = stoInboxHelper.cachedAccountId,
            CRM_Is_Read__c = false,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getRecentThreads();
        Test.stopTest();

        Assert.areEqual(false, tList.isEmpty());
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

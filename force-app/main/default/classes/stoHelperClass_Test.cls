@isTest
public with sharing class stoHelperClass_Test {
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
    }

    @isTest
    static void getThemesTest() {
        Test.startTest();
        List<STO_Category__mdt> themes = stoHelperClass.getThemes('no');
        List<STO_Category__mdt> themesen = stoHelperClass.getThemes('en-US');
        Test.stopTest();
        System.assertEquals(themes.isEmpty(), false, 'Missing metadata setup - initiate STO Category Themes');
    }
    @isTest
    static void createCaseTest() {
        Test.startTest();
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Test.stopTest();
        System.assertEquals('Web', c.Origin, 'Incorrect case origin - check case creation');
    }
    @isTest
    static void createThreadCaseTest() {
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Test.startTest();
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker');
        Test.stopTest();
        System.assertEquals(t.CRM_Related_Object__c, c.Id, 'Thread creation test failure, check thread');
    }
    @isTest
    static void createMessageTest() {
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker');
        Test.startTest();
        stoHelperClass.createMessage(t, 'this is a test message');
        Test.stopTest();
        List<Message__c> m = [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :t.Id];
        System.assertEquals('this is a test message', m.get(0).CRM_Message_Text__c);
    }
    @isTest
    static void getThreadsTest() {
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker');
        Test.startTest();
        List<Thread__c> tList = stoHelperClass.getThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    @isTest
    static void getLatestMessageTest() {
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker');
        stoHelperClass.createMessage(t, 'this is a test message again');
        Test.startTest();
        Message__c m = stoHelperClass.getLatestMessage(t.Id);
        Test.stopTest();
        System.assertEquals('this is a test message again', m.CRM_Message_Text__c);
    }
    @isTest
    static void createRequestTest() {
        Test.startTest();
        Id threadId = stoHelperClass.createRequest('Jobbsøker', 'This is the message');
        Test.stopTest();
        List<Message__c> msgList = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :threadId];
        System.assertEquals(1, msgList.size());
    }

    @isTest
    static void createNavTaskTest() {
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c());
        String accountId = [SELECT CRM_Account__c FROM Person__c LIMIT 1]?.CRM_Account__c;

        Test.startTest();
        stoHelperClass.createNavTask(accountId, thread.Id);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM NavTask__c]);
    }
}

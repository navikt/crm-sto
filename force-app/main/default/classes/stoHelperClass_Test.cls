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
    static void getOpenThreadsTest() {
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
            'STO',
            null,
            null
        );
        Test.startTest();
        System.assertNotEquals(null, stoHelperClass.getOpenThreads('Arbeid', 'STO'), 'Expected to get a thread');
        Test.stopTest();
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
    static void createThreadCaseTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];

        Test.startTest();
        Thread__c t = stoHelperClass.createThread(
            null,
            'Arbeid',
            personContact.AccountId,
            personContact.Id,
            true,
            'STO',
            null,
            null
        );
        Test.stopTest();
        System.assertNotEquals(null, t.Id);
    }
    @isTest
    static void createMessageTest() {
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
            'STO',
            null,
            null
        );
        Test.startTest();
        stoHelperClass.createMessage(t, 'this is a test message', personContact.Id);
        Test.stopTest();
        List<Message__c> m = [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :t.Id];
        System.assertEquals('this is a test message', m.get(0).CRM_Message_Text__c);
    }

    @isTest
    static void createThreadWithCaseTest() {
        Test.startTest();
        Thread__c thread = stoHelperClass.createThreadWithCase(
            'Arbeid',
            'This is the message',
            true,
            'STO',
            null,
            null
        );
        Test.stopTest();
        List<Message__c> msgList = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :thread.Id];
        System.assertEquals(1, msgList.size());
    }

    @isTest
    static void createThreadWithCaseMoreThanThreeThreadsErrorTest() {
        stoHelperClass.createThreadWithCase('Arbeid', 'This is the message', true, 'STO', null, null);
        stoHelperClass.createThreadWithCase('Arbeid', 'This is the message', true, 'STO', null, null);
        stoHelperClass.createThreadWithCase('Arbeid', 'This is the message', true, 'STO', null, null);
        Exception ex;

        Test.startTest();
        try {
            stoHelperClass.createThreadWithCase('Arbeid', 'This is the message', true, 'STO', null, null);
        } catch (Exception e) {
            ex = e;
        }
        Test.stopTest();

        Assert.areNotEqual(null, ex);
    }

    @isTest
    static void getNewsBasedOnThemeSTOTest() {
        Test.startTest();
        List<stoHelperClass.News> newsList = stoHelperClass.getNewsBasedOnTheme('Skriv til oss', 'Pensjon');
        System.assertEquals(newsList.isEmpty(), false);
        Test.stopTest();
    }

    @isTest
    static void getNewsBasedOnThemeBTOTest() {
        Test.startTest();
        List<stoHelperClass.News> newsList = stoHelperClass.getNewsBasedOnTheme('Beskjed til oss', 'Pensjon');
        System.assertEquals(newsList.isEmpty(), false);
        Test.stopTest();
    }

    @isTest
    static void closeThreadTest() {
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
            'STO',
            null,
            null
        );

        Test.startTest();
        stoHelperClass.closeThread(t.Id);
        Test.stopTest();

        Assert.areEqual(false, t.CRM_isActive__c);
    }
}

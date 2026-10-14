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

    private static Contact getContactBasedOnPersonIdent(String personIdent) {
        return [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = :personIdent
            LIMIT 1
        ];
    }

    private static stoHelperClass.ThreadData getThreadData() {
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.theme = 'Arbeid';
        info.msgText = 'This is the message';
        info.medskriv = true;
        info.type = 'STO';
        info.disabilityCampaign = false;
        setAccountAndContactIds(info, '12345678910');
        return info;
    }

    private static void setAccountAndContactIds(stoHelperClass.ThreadData info, String personIdent) {
        Contact personContact = getContactBasedOnPersonIdent(personIdent);
        info.cachedContactId = personContact.Id;
        info.cachedAccountId = personContact.AccountId;
    }

    @isTest
    static void getOpenThreadsTest() {
        stoHelperClass.ThreadData info = getThreadData();

        stoHelperClass.cachedAccountId = getContactBasedOnPersonIdent('12345678910')?.AccountId;

        Thread__c t = stoHelperClass.createThread(info);
        Test.startTest();
        Assert.areNotEqual(null, stoHelperClass.getOpenThreads('Arbeid', 'STO'), 'Expected to get a thread');
        Test.stopTest();
    }

    @isTest
    static void getThemesTest() {
        Test.startTest();
        List<STO_Category__mdt> themes = stoHelperClass.getThemes('no');
        List<STO_Category__mdt> themesEn = stoHelperClass.getThemes('en-US');
        Test.stopTest();

        Assert.areEqual(themes.isEmpty(), false, 'Missing metadata setup - initiate STO Category Themes');
    }

    @isTest
    static void createThreadCaseTest() {
        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        // info.representedPersonIdentifier = '12345678910';
        Test.startTest();
        Thread__c t = stoHelperClass.createThread(info);
        Test.stopTest();

        Assert.areNotEqual(null, t.Id, 'Thread should have been created and have an Id');
    }

    @isTest
    static void createMessageTest() {
        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        info.msgText = 'this is a test message';
        // info.representedPersonIdentifier = '12345678910';
        Thread__c t = stoHelperClass.createThread(info);
        Contact personContact = [
            SELECT Id
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Test.startTest();
        stoHelperClass.createMessage(t, info);
        Test.stopTest();
        List<Message__c> m = [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :t.Id];

        Assert.areEqual('this is a test message', m[0].CRM_Message_Text__c, 'Message text should match');
    }

    @isTest
    static void createThreadTest() {
        Test.startTest();
        stoHelperClass.ThreadData info = getThreadData();

        Thread__c thread = stoHelperClass.createThread(info);
        Test.stopTest();

        List<Message__c> msgList = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :thread.Id];
        Assert.areEqual(1, msgList.size(), 'Thread should contain exactly one message');
    }

    @isTest
    static void createThread_DisabilityCampaign_SetsSourceTest() {
        Test.startTest();
        stoHelperClass.ThreadData info = getThreadData();
        info.disabilityCampaign = true;
        Thread__c thread = stoHelperClass.createThread(info);
        Test.stopTest();

        Thread__c insertedThread = [
            SELECT NKS_Experience_Site_Source__c
            FROM Thread__c
            WHERE Id = :thread.Id
            LIMIT 1
        ];

        Assert.areEqual('Uforekampanje', insertedThread.NKS_Experience_Site_Source__c);
    }

    @isTest
    static void createThread_DisabilityCampaign_NullSourceWhenFalseTest() {
        Test.startTest();
        stoHelperClass.ThreadData info = getThreadData();
        Thread__c thread = stoHelperClass.createThread(info);
        Test.stopTest();

        Thread__c insertedThread = [
            SELECT NKS_Experience_Site_Source__c
            FROM Thread__c
            WHERE Id = :thread.Id
            LIMIT 1
        ];

        Assert.areEqual(null, insertedThread.NKS_Experience_Site_Source__c);
    }

    @isTest
    static void createThreadMoreThanThreeThreadsErrorTest() {
        stoHelperClass.ThreadData info = getThreadData();
        stoHelperClass.createThread(info);
        stoHelperClass.createThread(info);
        stoHelperClass.createThread(info);
        Exception ex;

        Test.startTest();
        try {
            stoHelperClass.createThread(info);
        } catch (Exception e) {
            ex = e;
        }
        Test.stopTest();

        Assert.areNotEqual(null, ex, 'Exception expected when creating more than three threads');
    }

    @isTest
    static void getNewsBasedOnThemeSTOTest() {
        Test.startTest();
        List<stoHelperClass.News> newsList = stoHelperClass.getNewsBasedOnTheme('Skriv til oss', 'Pensjon');
        Test.stopTest();

        Assert.isTrue(!newsList.isEmpty(), 'Expected at least one news item for STO theme');
    }

    @isTest
    static void getNewsBasedOnThemeBTOTest() {
        Test.startTest();
        List<stoHelperClass.News> newsList = stoHelperClass.getNewsBasedOnTheme('Beskjed til oss', 'Pensjon');
        Test.stopTest();

        Assert.isTrue(!newsList.isEmpty(), 'Expected at least one news item for BTO theme');
    }

    @isTest
    static void closeThreadTest() {
        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        Thread__c t = stoHelperClass.createThread(info);
        Test.startTest();
        stoHelperClass.closeThread(t.Id);
        Test.stopTest();

        Assert.areEqual(false, t.CRM_isActive__c, 'Thread should be closed');
    }

    @isTest
    static void testPutCloseIntent_GreaterThanOrEqualTo3() {
        User u = [SELECT Id, NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            stoHelperClass.putCloseIntent(3);
            Test.stopTest();

            User updatedUser = [SELECT NKS_Close_Intent__c FROM User WHERE Id = :u.Id];
            Assert.areEqual(true, updatedUser.NKS_Close_Intent__c, 'Close intent should be true when count >= 3');
        }
    }

    @isTest
    static void testPutCloseIntent_LessThan3() {
        User u = [SELECT Id, NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            stoHelperClass.putCloseIntent(2);
            Test.stopTest();

            User updatedUser = [SELECT NKS_Close_Intent__c FROM User WHERE Id = :u.Id];
            Assert.areEqual(false, updatedUser.NKS_Close_Intent__c, 'Close intent should be false when count < 3');
        }
    }

    @isTest
    static void testGetCloseIntent_True() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        u.NKS_Close_Intent__c = true;
        update u;

        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        List<Thread__c> threads = new List<Thread__c>();
        for (Integer i = 0; i < 3; i++) {
            threads.add(stoHelperClass.createThread(info));
        }

        System.runAs(u) {
            Test.startTest();
            Boolean result = stoHelperClass.getCloseIntent('Arbeid');
            Test.stopTest();

            Assert.areEqual(
                true,
                result,
                'Should return true if NKS_Close_Intent__c is true and canUserCloseThread returns true'
            );
        }
    }

    @isTest
    static void testGetCloseIntent_FalseDueToFlag() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        u.NKS_Close_Intent__c = false;
        update u;

        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        List<Thread__c> threads = new List<Thread__c>();
        for (Integer i = 0; i < 3; i++) {
            threads.add(stoHelperClass.createThread(info));
        }

        System.runAs(u) {
            Test.startTest();
            Boolean result = stoHelperClass.getCloseIntent('Arbeid');
            Test.stopTest();

            Assert.areEqual(
                false,
                result,
                'Should return false if NKS_Close_Intent__c is false even if canUserCloseThread returns true'
            );
        }
    }

    @isTest
    static void testGetCloseIntent_FalseDueToCount() {
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        u.NKS_Close_Intent__c = true;
        update u;
        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        Thread__c testThread = stoHelperClass.createThread(info);

        System.runAs(u) {
            Test.startTest();
            Boolean result = stoHelperClass.getCloseIntent('Arbeid');
            Test.stopTest();

            Assert.areEqual(
                false,
                result,
                'Should return false if canUserCloseThread returns false even if NKS_Close_Intent__c is true'
            );
        }
    }

    @isTest
    static void getCodeToNameMapTest() {
        Test.startTest();
        Map<String, String> result = stoHelperClass.getCodeToNameMap();
        Test.stopTest();

        Assert.isFalse(result.isEmpty());
    }

    @isTest
    static void testGetThread() {
        // Contact personContact = getContactBasedOnPersonIdent('12345678910');
        stoHelperClass.ThreadData info = getThreadData();

        info.inboxTitle = 'Inbox title test';
        info.inboxTheme = 'Inbox theme test';
        Thread__c created = stoHelperClass.createThread(info);

        Test.startTest();
        Thread__c fetched = stoHelperClass.getThread(created.Id);
        Test.stopTest();

        Assert.isNotNull(fetched, 'Expected thread to be returned');
        Assert.areEqual(created.Id, fetched.Id, 'Returned thread Id should match');
        Assert.areEqual('STO', fetched.CRM_Thread_Type__c, 'Expected STO thread type');
        Assert.areEqual('Arbeid', fetched.STO_Category__c, 'Expected category to match');
    }
}

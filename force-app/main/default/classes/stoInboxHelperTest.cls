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

    private static stoHelperClass.ThreadData getThreadData() {
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.theme = 'Arbeid';
        info.msgText = 'This is the message';
        info.medskriv = true;
        info.type = 'STO';
        info.inboxTitle = 'Skriv til oss';
        info.inboxTheme = 'Arbeid';
        return info;
    }

    @isTest
    static void getThreadsTest() {
        stoHelperClass.ThreadData threadData = getThreadData();
        threadData.msgText = 'Dette er en test melding';
        Thread__c t = stoHelperClass.createThread(threadData);
        Message__c message = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :t.Id LIMIT 1];
        t.CRM_Closed_Date__c = Date.today().addDays(-1);
        update t;

        Conversation_Note__c cn = new Conversation_Note__c(
            CRM_Is_Read__c = true,
            CRM_Created_by_Ident__c = 'A123456',
            CRM_Conversation_Note__c = 'this is a test message again'
        );
        insert cn;

        Test.startTest();
        stoThreadReadState.markThreadRead(t.Id, message.Id);
        List<stoInboxHelper.thread> tList = stoInboxHelper.getThreads();
        Test.stopTest();

        Assert.areEqual(false, tList.isEmpty());
        Assert.areEqual(2, tList.size());
    }

    @isTest
    static void getRecentThreadsTest() {
        Thread__c t = stoHelperClass.createThread(getThreadData());
        Message__c m = new Message__c();
        m.CRM_Thread__c = t.Id;
        insert m;

        Conversation_Note__c cn = new Conversation_Note__c(
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
    static void threadPreviewKeepsIncomingFiveHundredCharacterLimit() {
        stoHelperClass.ThreadData info = getThreadData();
        info.msgText = 'x'.repeat(650);
        Thread__c thread = stoHelperClass.createThread(info);
        Test.startTest();
        stoInboxHelper.thread item = stoInboxHelper.getRecentThreads()[0];
        Test.stopTest();
        Assert.areEqual(thread.Id, item.recordId);
        Assert.areEqual(500, item.latestmessage.messageText.length());
        Assert.areEqual(
            650,
            [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :thread.Id LIMIT 1]
                .CRM_Message_Text__c.length(),
            'Only the preview should be truncated'
        );
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

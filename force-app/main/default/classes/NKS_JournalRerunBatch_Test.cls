@IsTest
public class NKS_JournalRerunBatch_Test {
    @TestSetup
    static void makeData() {
        Conversation_Note__c convNote = (Conversation_Note__c) STO_TestDataFactory.createRecord(
            new Conversation_Note__c()
        );
        Journal_Entry__c je = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Conversation_Note__c = convNote.Id)
        );
        Thread__c chatThread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c(CRM_Thread_Type__c = 'CHAT'));
        Journal_Entry__c je2 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = chatThread.Id)
        );
        Thread__c stoThread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c(CRM_Thread_Type__c = 'STO'));
        STO_TestDataFactory.createRecord(new Message__c(CRM_Thread__c = stoThread.Id, CRM_Message_Text__c = 'En melding.'));
        STO_TestDataFactory.createRecord(new Message__c(CRM_Thread__c = stoThread.Id, CRM_Message_Text__c = 'En melding.'));
        STO_TestDataFactory.createRecord(new Message__c(CRM_Thread__c = stoThread.Id, CRM_Message_Text__c = 'En melding.'));
        Journal_Entry__c je3 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = stoThread.Id)
        );
        Thread__c stbThread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c(CRM_Thread_Type__c = 'STB'));
        Journal_Entry__c je4 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = stbThread.Id)
        );
    }

    @IsTest
    static void processJournalSuffixTest() {
        ApiMock.setTestMock('POST_CREATE_JOURNAL', 200, 'OK');
        List<Journal_Entry__c> oldJEntries = [SELECT Id, Journal_Entry_Status__c FROM Journal_Entry__c];
        String normalSuffix = 'NormalSuffix';
        List<NKS_JournalRerunBatch.JournalRerunWrapper> inputs = new List<NKS_JournalRerunBatch.JournalRerunWrapper>();
        NKS_JournalRerunBatch.JournalRerunWrapper input = new NKS_JournalRerunBatch.JournalRerunWrapper();
        input.scope = 'Id != null';
        input.externalReferenceSuffix = normalSuffix;
        inputs.add(input);
        Test.startTest();
        NKS_JournalRerunBatch.initJournalBatcher(inputs);
        Test.stopTest();
        List<Journal_Entry__c> newJEntries = [SELECT Id, Journal_Entry_Status__c FROM Journal_Entry__c];
        Assert.areEqual(4, oldJEntries.size());
        Assert.areEqual(4, newJEntries.size());
    }
}

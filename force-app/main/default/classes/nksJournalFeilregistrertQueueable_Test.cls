@IsTest
public with sharing class nksJournalFeilregistrertQueueable_Test {

    @TestSetup
    static void makeData(){
        Conversation_Note__c convNote = (Conversation_Note__c) STO_TestDataFactory.createRecord(
            new Conversation_Note__c()
        );
        Journal_Entry__c je = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Conversation_Note__c = convNote.Id)
        );
        Thread__c chatThread = (Thread__c) STO_TestDataFactory.createRecord(
        new Thread__c(CRM_Type__c = 'CHAT')
        );
        Journal_Entry__c je2 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = chatThread.Id)
        );
        Thread__c stoThread = (Thread__c) STO_TestDataFactory.createRecord(
        new Thread__c(CRM_Type__c = 'STO')
        );
        Journal_Entry__c je3 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = stoThread.Id)
        );
        Thread__c stbThread = (Thread__c) STO_TestDataFactory.createRecord(
        new Thread__c(CRM_Type__c = 'STB')
        );
        Journal_Entry__c je4 = (Journal_Entry__c) STO_TestDataFactory.createRecord(
            new Journal_Entry__c(CRM_Thread__c = stbThread.Id)
        );
        
    }

    @IsTest
    static void processJournalTest(){
        ApiMock.setTestMock('POST_CREATE_JOURNAL', 200, 'OK');
        List<Journal_Entry__c> oldJEntries = [Select Id, Journal_Entry_Status__c from Journal_Entry__c];
        Test.startTest();
        new nksJournalFeilregistrertQueueable();
        Test.stopTest();
        List<Journal_Entry__c> newJEntries = [Select Id, Journal_Entry_Status__c from Journal_Entry__c];
        Assert.areEqual(4, oldJEntries.size());
        Assert.areEqual(4, newJEntries.size());
    }
}
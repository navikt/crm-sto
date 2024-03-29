@isTest
public class STO_ThreadJournalBatcher_Test {
    @TestSetup
    static void makeData() {
        Common_Code__c comCode = (Common_Code__c) STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Dagpenger', CRM_Code__c = 'DAG', CRM_Code_Set__c = 'Tema')
        );
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(
            new Thread__c(CRM_isActive__c = false, CRM_Thread_Type__c = 'STO')
        );
        STO_TestDataFactory.createRecord(
            new Message__c(CRM_Message_Text__c = 'TEST MESSAGE', CRM_Thread__c = thread.Id)
        );

        //FAGSAK
        STO_TestDataFactory.createRecord(
            new Journal_Entry__c(
                CRM_Thread__c = thread.Id,
                NAV_Case_Reference__c = '123BSHSF',
                CRM_NAV_Case_Legacy_System__c = 'A01',
                Theme__c = comCode.Id,
                CRM_Created_By_NAV_Unit__c = '4100',
                Journal_Entry_Status__c = 'In Progress'
            )
        );

        //GENERELL_SAK
        STO_TestDataFactory.createRecord(
            new Journal_Entry__c(
                CRM_Thread__c = thread.Id,
                Theme__c = comCode.Id,
                CRM_Created_By_NAV_Unit__c = '4100',
                Journal_Entry_Status__c = 'In Progress'
            )
        );
    }

    @isTest
    static void testJournalBatch() {
        ApiMock.setTestMock('POST_CREATE_JOURNAL', 200, 'OK');

        Test.startTest();
        STO_ThreadJournalBatcher.initThreadJournalBatcher();
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Journal_Entry__c WHERE Journal_Entry_Status__c = 'Completed']);
        System.assertEquals(1, [SELECT COUNT() FROM Thread__c WHERE CRM_Journal_Status__c = 'Journal Completed']);
    }

    @isTest
    static void testJournalBatchWithSensitiveThread() {
        Thread__c thread = [SELECT Id FROM Thread__c LIMIT 1];
        thread.STO_Sensitive_Information__c = true; //Thread is awaiting "sladding"
        update thread;

        Test.startTest();
        STO_ThreadJournalBatcher.initThreadJournalBatcher();
        Test.stopTest();

        //No journal entries should have been posted
        System.assertEquals(0, [SELECT COUNT() FROM Journal_Entry__c WHERE Journal_Entry_Status__c = 'Completed']);
    }
}

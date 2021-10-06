@isTest
public class STO_ThreadJournalBatcher_Test {
    @TestSetup
    static void makeData() {
        Common_Code__c comCode = (Common_Code__c) STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Dagpenger', CRM_Code__c = 'DAG', CRM_Code_Set__c = 'Tema')
        );
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c(CRM_isActive__c = false));
        STO_TestDataFactory.createRecord(
            new Message__c(CRM_Message_Text__c = 'TEST MESSAGE', CRM_Thread__c = thread.Id)
        );
        STO_TestDataFactory.createRecord(
            new Journal_Entry__c(
                CRM_Thread__c = thread.Id,
                NAV_Case_Reference__c = '123BSHSF',
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

        System.assertEquals(1, [SELECT COUNT() FROM Journal_Entry__c WHERE Journal_Entry_Status__c = 'Completed']);
        System.assertEquals(1, [SELECT COUNT() FROM Thread__c WHERE CRM_Journal_Status__c = 'Journal Completed']);
    }
}

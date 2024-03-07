@isTest
private class UpdateCaseSubjectsBatchTest {
    @isTest
    static void testBatchExecution() {
        // Create test data - Thread records with associated Cases
        List<Thread__c> threads = new List<Thread__c>();
        List<Case> cases = new List<Case>();

        Case testCase = new Case();
        Case testCase2 = new Case();
        cases.add(testCase);
        cases.add(testCase2);
        insert cases;

        Thread__c testThread = new Thread__c(
            CRM_Case__c = testCase.Id,
            CRM_Thread_Type__c = 'STO',
            CRM_Type__c = 'STO'
        );
        Thread__c testThread2 = new Thread__c(
            CRM_Case__c = testCase2.Id,
            CRM_Thread_Type__c = 'STO',
            CRM_Type__c = 'STO'
        );
        threads.add(testThread);
        threads.add(testThread2);
        insert threads;

        Test.startTest();
        System.debug(
            [
                SELECT STO_ExternalName__c, CRM_Case__c, CRM_Case__r.Subject, CRM_Is_Closed__c, CRM_Thread_Type__c
                FROM Thread__c
            ]
        );
        UpdateCaseSubjectsBatch batch = new UpdateCaseSubjectsBatch();
        Database.executeBatch(batch);
        Test.stopTest();

        List<Case> updatedCases = [SELECT Id, Subject FROM Case WHERE Id IN :cases];
        Assert.areNotEqual(null, updatedCases[0].Subject);
        Assert.areNotEqual(null, updatedCases[1].Subject);
    }
}

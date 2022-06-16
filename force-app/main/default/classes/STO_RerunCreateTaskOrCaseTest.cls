@isTest
public with sharing class STO_RerunCreateTaskOrCaseTest {
    @isTest
    public static void testSheduler() {
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c());
        List<Id> testInput = new List<Id>();
        testInput.add(thread.Id);

        Test.startTest();
        String s = STO_RerunCreateTaskOrCaseOnFaultSchd.scheduleCreateTaskOrCase(testInput)[0];
        Test.stopTest();

        System.assertEquals(STO_RerunCreateTaskOrCaseOnFaultSchd.SUCCESS, s);
        String cronJobName = STO_RerunCreateTaskOrCaseOnFaultSchd.JOB_NAME_PREFIX + String.valueOf(thread.Id);
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :cronJobName
        ];

        System.assertEquals(1, jobs.size(), 'One job expectet');
    }
    @isTest
    public static void testShedulerTwoJobs() {
        Thread__c thread = (Thread__c) STO_TestDataFactory.createRecord(new Thread__c());
        List<Id> testInput = new List<Id>();
        testInput.add(thread.Id);

        Test.startTest();
        STO_RerunCreateTaskOrCaseOnFaultSchd.scheduleCreateTaskOrCase(testInput);
        String s = STO_RerunCreateTaskOrCaseOnFaultSchd.scheduleCreateTaskOrCase(testInput)[0];
        Test.stopTest();

        System.assertNotEquals(
            STO_RerunCreateTaskOrCaseOnFaultSchd.SUCCESS,
            s,
            'ERROR expected while scheduling second job with same name'
        );
        String cronJobName = STO_RerunCreateTaskOrCaseOnFaultSchd.JOB_NAME_PREFIX + String.valueOf(thread.Id);
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = :cronJobName
        ];

        System.assertEquals(1, jobs.size(), 'One job expectet');
    }
}

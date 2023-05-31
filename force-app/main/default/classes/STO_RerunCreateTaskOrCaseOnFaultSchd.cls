/**
 * @description Class for rerunning Task/Case creation and assignment to
 * thread, if original attempt failed.
 */
public with sharing class STO_RerunCreateTaskOrCaseOnFaultSchd implements Database.Batchable<sObject> {
    public static final String JOB_NAME_PREFIX = 'RerunCreateTaskOrCase';
    public static final String SUCCESS = 'SUCCESS';
    public final String query;
    public final Id threadId;
    public STO_RerunCreateTaskOrCaseOnFaultSchd(Id thread) {
        threadId = thread;
        query =
            'SELECT ' +
            'Id, ' +
            'Name, ' +
            'CRM_Account__c, ' +
            'STO_Category__c, ' +
            'CRM_Account__r.CRM_Person__r.INT_IsNavEmployee__c, ' +
            'CRM_Account__r.CRM_Person__r.INT_Confidential__c, ' +
            'CRM_Related_Object__c, ' +
            'CRM_API_Reference__c, ' +
            'CRM_Thread_Type__c ' +
            'FROM Thread__c ' +
            'WHERE Id = :threadId';
    }
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }
    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Thread__c> threads = new List<Thread__c>();
        for (Sobject s : scope) {
            Map<String, Object> input = new Map<String, Object>();
            input.put('Thread', (Thread__c) s);
            Flow.Interview.STO_Thread_CreateTaskOrCase reRunFlow = new Flow.Interview.STO_Thread_CreateTaskOrCase(
                input
            );
            reRunFlow.start();
        }
    }
    public void finish(Database.BatchableContext BC) {
        // Not in use
    }
    /**
     * @description Method runs form the flow to schedule rerunning in 5min
     * @param threads [Id of the thread to schedule rerunning]
     * @return 'SUCCESS' on success
     **/
    @InvocableMethod(label='RerunCreateTaskOrCase' description='Scheduled rerun of CreateTaskOrCase')
    public static List<String> scheduleCreateTaskOrCase(List<Id> threads) {
        List<String> returnValue = new List<String>();
        if (threads == null || threads.size() != 1) {
            returnValue.add('ERROR: One Thread__c Id should be provided.');
            return returnValue;
        }
        String cronJobName = JOB_NAME_PREFIX + String.valueOf(threads[0]);
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name, NextFireTime, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = :cronJobName
        ];
        if (!jobs.isEmpty()) {
            returnValue.add(
                'ERROR: job for thread ' +
                String.valueOf(threads[0]) +
                'already exist. State: ' +
                jobs[0].State
            );
            return returnValue;
        }
        STO_RerunCreateTaskOrCaseOnFaultSchd newJob = new STO_RerunCreateTaskOrCaseOnFaultSchd(threads[0]);
        System.scheduleBatch(newJob, cronJobName, 5);
        returnValue.add(SUCCESS);
        return returnValue;
    }
}

public with sharing class STO_ClosedCasesInternalQueueBatch implements Database.Batchable<SObject>, Schedulable {
    public static final String QUEUE_DEVELOPER_NAME = 'Closed_STO_Cases_Internal';

    public void execute(SchedulableContext context) {
        // Reassigning ~2M cases causes heavy sharing recalculation, so only run on weekends
        if (isWeekend()) {
            Database.executeBatch(new STO_ClosedCasesInternalQueueBatch(), 2000);
        }
    }

    private static Boolean isWeekend() {
        String dayOfWeek = Datetime.now().format('EEEE');
        return dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday';
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            'SELECT Id, OwnerId FROM Case WHERE Status = \'Closed\' AND RecordType.DeveloperName IN (\'Phone_Case\', \'STO_Case\') AND Owner.Profile.Name LIKE \'nav kontaktsenter%\''
        );
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        Group queue = [SELECT Id FROM Group WHERE DeveloperName = :QUEUE_DEVELOPER_NAME AND Type = 'Queue' LIMIT 1];
        List<Case> cases = (List<Case>) scope;
        for (Case c : cases) {
            c.OwnerId = queue.Id;
        }
        update cases;
    }

    public void finish(Database.BatchableContext BC) {
    }
}

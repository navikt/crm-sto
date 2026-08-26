public with sharing class STO_ClosedCasesInternalQueueBatch implements Database.Batchable<SObject>, Schedulable {
    public static final String QUEUE_DEVELOPER_NAME = 'Closed_STO_Cases_Internal';

    public void execute(SchedulableContext context) {
        // Reassigning ~2M cases causes heavy sharing recalculation, so only run outside of office hours
        if ((isWeekend() || isEvening()) && !isAlreadyRunning()) {
            Database.executeBatch(new STO_ClosedCasesInternalQueueBatch(), 200);
        }
    }

    // Prevents overlapping runs (e.g. a previous run still processing when the 3-hour cron fires again)
    // from concurrently reassigning the same Cases, which causes UNABLE_TO_LOCK_ROW
    private static Boolean isAlreadyRunning() {
        return ![
                SELECT Id
                FROM AsyncApexJob
                WHERE
                    ApexClass.Name = :STO_ClosedCasesInternalQueueBatch.class.getName()
                    AND JobType = 'BatchApex'
                    AND Status IN ('Processing', 'Preparing', 'Queued', 'Holding')
            ]
            .isEmpty();
    }

    private static Boolean isWeekend() {
        String dayOfWeek = Datetime.now().format('EEEE');
        return dayOfWeek == 'Saturday' || dayOfWeek == 'Sunday';
    }

    private static Boolean isEvening() {
        Integer currentHour = Integer.valueOf(Datetime.now().format('H'));
        return currentHour < 5 || currentHour >= 19;
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
        Database.update(cases, false);
    }

    public void finish(Database.BatchableContext BC) {
    }
}

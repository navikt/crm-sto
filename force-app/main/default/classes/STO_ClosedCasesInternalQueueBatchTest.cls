@isTest
private class STO_ClosedCasesInternalQueueBatchTest {
    @isTest
    static void testMovesClosedCasesToQueue() {
        Group queue = new Group(
            Name = 'Closed STO Cases Internal',
            DeveloperName = 'Closed_STO_Cases_Internal',
            Type = 'Queue'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert queue;
            insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
        }

        Case testCase = new Case(Status = 'Closed');
        insert testCase;

        STO_ClosedCasesInternalQueueBatch batch = new STO_ClosedCasesInternalQueueBatch();

        Test.startTest();
        batch.start(null);
        batch.execute(null, new List<Case>{ testCase });
        batch.finish(null);
        Test.stopTest();

        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual(queue.Id, updatedCase.OwnerId);
    }

    @isTest
    static void testScheduledBatchRuns() {
        Group queue = new Group(
            Name = 'Closed STO Cases Internal',
            DeveloperName = 'Closed_STO_Cases_Internal',
            Type = 'Queue'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert queue;
            insert new QueueSobject(QueueId = queue.Id, SobjectType = 'Case');
        }

        Test.startTest();
        System.schedule(
            'Closed STO Cases Internal Queue Test Job',
            '0 0 2 * * ?',
            new STO_ClosedCasesInternalQueueBatch()
        );
        Test.stopTest();
    }
}

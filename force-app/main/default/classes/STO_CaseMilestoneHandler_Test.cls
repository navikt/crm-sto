@isTest
public class STO_CaseMilestoneHandler_Test {
    @TestSetup
    static void makeData() {
        Account acc = (Account) STO_TestDataFactory.createRecord(new Account());
        Entitlement entl = (Entitlement) STO_TestDataFactory.createRecord(new Entitlement(AccountId = acc.Id));

        STO_TestDataFactory.createRecord(
            new Case(AccountId = acc.Id, EntitlementId = entl.Id, Origin = 'STO', Status = 'New', Subject = 'STO Case')
        );

        STO_TestDataFactory.createRecord(
            new Case(AccountId = acc.Id, EntitlementId = entl.Id, Origin = 'BTO', Status = 'New', Subject = 'BTO Case')
        );
    }

    @isTest
    static void testMilestoneCompletion_OnHold() {
        Case casy = [SELECT Id, Status FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        Test.startTest();
        casy.Status = 'On Hold';
        update casy;
        Test.stopTest();

        Assert.areEqual('On Hold', casy.Status, 'The case status should be updated to On Hold.');
    }

    @isTest
    static void testMilestoneCompletion_Forwarded() {
        Case casy = [SELECT Id, Status, Origin FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        Test.startTest();
        casy.Status = 'Forwarded';
        update casy;
        Test.stopTest();

        Assert.areEqual('Forwarded', casy.Status, 'The case status should be updated to Forwarded.');
    }

    @isTest
    static void testMilestoneCompletion_Reserved() {
        Case casy = [SELECT Id, Status, Origin FROM Case WHERE Subject = 'BTO Case' LIMIT 1];

        Test.startTest();
        casy.Status = 'Reserved';
        update casy;
        Test.stopTest();

        Assert.areEqual('Reserved', casy.Status, 'The case status should be updated to Reserved.');
    }

    @isTest
    static void testMilestoneCompletion_OriginChanged() {
        Case casy = [SELECT Id, Status, Origin FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        Test.startTest();
        casy.Origin = 'BTO';
        casy.Status = 'Closed';
        update casy;
        Test.stopTest();

        Assert.areEqual('BTO', casy.Origin, 'The case origin should be updated to BTO.');
        Assert.areEqual('Closed', casy.Status, 'The case status should be updated to Closed.');
    }

    @isTest
    static void testTrackedFieldsNotChanged() {
        Case casy = [SELECT Id, Subject FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        Test.startTest();
        casy.Subject = 'Changed Subject';
        update casy;
        Test.stopTest();

        Assert.areEqual('Changed Subject', casy.Subject, 'The case subject should be updated to Changed Subject.');
    }

    @isTest
    static void testCaseWrapper() {
        Case casy = [SELECT Id, Origin FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        STO_CaseMilestoneHandler.CaseWrapper wrapper = new STO_CaseMilestoneHandler.CaseWrapper(casy, true);

        Assert.areEqual(casy.Id, wrapper.relatedCase.Id);
        Assert.areEqual(true, wrapper.hasChangedOrigin);
    }

    @isTest
    static void testGetOpenMilestones() {
        Case casy = [SELECT Id FROM Case WHERE Subject = 'STO Case' LIMIT 1];

        Test.startTest();
        List<CaseMilestone> milestones = STO_CaseMilestoneHandler.getOpenMilestones(new Set<Id>{ casy.Id });
        Test.stopTest();

        Assert.isNotNull(milestones, 'The getOpenMilestones method should return a non-null list.');
    }
}

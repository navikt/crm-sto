@isTest
public class STO_CaseMilestoneHandler_Test {
    @TestSetup
    static void makeData() {
        Account acc = (Account) STO_TestDataFactory.createRecord(new Account());
        Entitlement entl = (Entitlement) STO_TestDataFactory.createRecord(new Entitlement(AccountId = acc.Id));
        Case casy = (Case) STO_TestDataFactory.createRecord(
            new Case(AccountId = acc.Id, EntitlementId = entl.Id, Origin = 'STO')
        );
    }

    @isTest
    static void testMilestoneCompletion() {
        Case casy = [SELECT Id FROM Case WHERE Origin = 'STO' LIMIT 1];

        Test.startTest();
        casy.Status = 'On Hold';
        update casy;
        Test.stopTest();
    }
}

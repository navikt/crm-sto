@isTest
public class STO_StoSlaTimeCalculator_Test {
    private static STO_StoSlaTimeCalculator calculator = new STO_StoSlaTimeCalculator();

    @isTest
    static void testTimeCalculation() {
        Case casy = (Case) STO_TestDataFactory.createRecord(new Case());

        Test.startTest();
        Integer milestoneMinutes = calculator.calculateMilestoneTriggerTime(casy.Id, null);
        Test.stopTest();

        System.assert(milestoneMinutes > 0);
    }
}

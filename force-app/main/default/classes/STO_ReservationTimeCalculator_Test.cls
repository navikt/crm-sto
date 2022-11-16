@isTest
public class STO_ReservationTimeCalculator_Test {
    private static STO_ReservationTimeCalulator calculator = new STO_ReservationTimeCalulator();
    
    @isTest
    static void triggerTest(){
        Time t1 = Datetime.now().time();
        Time t2 = Time.newInstance(21, 0, 0, 0);
        Integer dt = t1 < t2 ?
            (t2.addHours(-t1.hour())).hour() * 60 + (t2.addMinutes(-t1.minute())).minute():
            5;

        Case casy = (Case) STO_TestDataFactory.createRecord(new Case());

        Test.startTest();
        Integer milestoneMinutes = calculator.calculateMilestoneTriggerTime(casy.Id, null);
        Test.stopTest();
        
        System.assert(dt >= milestoneMinutes && dt <= milestoneMinutes + 1);
    }
}

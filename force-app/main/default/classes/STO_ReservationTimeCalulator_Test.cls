@isTest
public class STO_ReservationTimeCalulator_Test {
    private static STO_ReservationTimeCalulator calculator = new STO_ReservationTimeCalulator();

    @isTest
    static void testReservationCalculation() {
        Test.startTest();
        Integer reservationTime = calculator.calculateMilestoneTriggerTime('test12324', '12345354');
        Test.stopTest();
    }
}

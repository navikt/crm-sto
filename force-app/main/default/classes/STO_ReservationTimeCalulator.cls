global without sharing class STO_ReservationTimeCalulator implements Support.MilestoneTriggerTimeCalculator {

    private Id STO_BUSINESS_HOURS_ID {
        get {
            if (STO_BUSINESS_HOURS_ID == null) {
                Id stoBusId = [SELECT Id FROM BusinessHours WHERE Name = 'STO Business Hours']?.Id;
                if (stoBusId == null) {
                    stoBusId = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE]?.Id;
                }
                STO_BUSINESS_HOURS_ID = stoBusId;
            }
            return STO_BUSINESS_HOURS_ID;
        }
        private set {
        }
    }

    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {

        Datetime now = Datetime.now();
        Datetime nextStartDate;
        Id bhId = STO_BUSINESS_HOURS_ID;
        
        nextStartDate = BusinessHours.nextStartDate(
            bhId,
            Datetime.newInstance(
                now.date().addDays(1),
                Time.newInstance(0,0,0,0)
            )
        );
        Long diff = BusinessHours.diff(bhId, now, nextStartDate);
        return (diff /1000 /60).intValue();
    }
}

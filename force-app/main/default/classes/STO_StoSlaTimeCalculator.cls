global without sharing class STO_StoSlaTimeCalculator implements Support.MilestoneTriggerTimeCalculator {
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
    private TimeZone osloTimezone = TimeZone.getTimeZone('Europe/Oslo');

    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {
        CaseMilestone openSlaMilestone;
        Date slaDate;
        try {
            openSlaMilestone = [
                SELECT Id, TargetResponseInMins
                FROM CaseMilestone
                WHERE CaseId = :caseId AND IsCompleted = FALSE
                LIMIT 1
            ];
        } catch (Exception ex) {
            //No currently open SLA milestones in the case
        }
        if (openSlaMilestone != null) {
            return openSlaMilestone.TargetResponseInMins;
        } else {
            slaDate = addBusinessDays(System.today(), 2);
            Datetime endOfSlaDate = Datetime.newInstance(slaDate, Time.newInstance(23, 59, 59, 59));
            endOfSlaDate.addSeconds(-osloTimezone.getOffset(endOfSlaDate) / 1000);
            return getMinutesBetween(endOfSlaDate, System.now());
        }
    }

    /**
     * @description: Calculates the number of minutes between two datetimes relative to the business hours
     * @author Stian Ruud Schikora | 11-18-2021
     * @param dt1
     * @param dt2
     * @return Integer
     **/
    private Integer getMinutesBetween(Datetime dt1, Datetime dt2) {
        Long msBetween = BusinessHours.diff(STO_BUSINESS_HOURS_ID, dt1, dt2);
        //msBetween += osloTimezone.getOffset(dt2); //Handling the timezone offset in the SLA calculation
        Double secondsBetween = msBetween < 0
            ? Double.valueOf(-1 * msBetween / 1000)
            : Double.valueOf(msBetween / 1000);
        return Integer.valueOf(Math.floor(secondsBetween / 60));
    }

    /**
     * @description: Adds a given number of business days to a startdate following the STO business hours
     * @author Stian Ruud Schikora | 11-18-2021
     * @param startDate
     * @param businessDaysToAdd
     * @return Date
     **/
    public Date addBusinessDays(Date startDate, Integer businessDaysToAdd) {
        Date slaDate = startDate;

        Integer businessDaysAdded = 0;
        while (businessDaysAdded < businessDaysToAdd) {
            slaDate = slaDate.addDays(1);
            if (BusinessHours.isWithin(STO_BUSINESS_HOURS_ID, slaDate)) {
                businessDaysAdded++;
            }
        }

        return slaDate;
    }
}

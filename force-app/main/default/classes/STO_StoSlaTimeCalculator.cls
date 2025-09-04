global without sharing class STO_StoSlaTimeCalculator implements Support.MilestoneTriggerTimeCalculator {
    private static Id STO_BUSINESS_HOURS_ID;
    // Returns cached BusinessHours Id (queried once per transaction)
    private static Id getBusinessHoursId() {
        if (STO_BUSINESS_HOURS_ID == null) {
            STO_BUSINESS_HOURS_ID = [
                SELECT Id
                FROM BusinessHours
                WHERE Name = 'STO Business Hours'
                LIMIT 1
            ]?.Id;

            if (STO_BUSINESS_HOURS_ID == null) {
                STO_BUSINESS_HOURS_ID = [
                    SELECT Id
                    FROM BusinessHours
                    WHERE IsDefault = TRUE
                    LIMIT 1
                ]?.Id;
            }
        }
        return STO_BUSINESS_HOURS_ID;
    }
    private TimeZone osloTimezone = TimeZone.getTimeZone('Europe/Oslo');
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String RESPOND_BTO_TYPE_NAME = 'Respond BTO';

    /**
     * Description: Calculates the time trigger for the Respond STO/BTO Milestone (the amount of time in which the milestone must be completed).
     * TargetResponseInMins field: The time to complete the milestone in minutes.
     * Runs on Case update/insert when Milestone criteria are met.
     */
    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {
        CaseMilestone openSlaMilestone;
        Date slaDate;
        try {
            openSlaMilestone = [
                SELECT Id, TargetResponseInMins
                FROM CaseMilestone
                WHERE
                    CaseId = :caseId
                    AND IsCompleted = FALSE
                    AND (MilestoneType.Name = :RESPOND_STO_TYPE_NAME
                    OR MilestoneType.Name = :RESPOND_BTO_TYPE_NAME)
                LIMIT 1
            ];
        } catch (Exception e) {
            // No existing Milestone
        }
        if (openSlaMilestone != null) {
            return openSlaMilestone.TargetResponseInMins;
        }

        slaDate = addBusinessDays(System.today(), 2);
        Datetime endOfSlaDate = Datetime.newInstance(slaDate, Time.newInstance(23, 59, 59, 59));
        endOfSlaDate.addSeconds(-osloTimezone.getOffset(endOfSlaDate) / 1000);
        return getMinutesBetween(endOfSlaDate, System.now());
    }

    /**
     * @description: Calculates the number of minutes between two datetimes relative to the business hours
     * @author Stian Ruud Schikora | 11-18-2021
     * @param dt1
     * @param dt2
     * @return Integer
     **/
    private Integer getMinutesBetween(Datetime dt1, Datetime dt2) {
        Long msBetween = BusinessHours.diff(getBusinessHoursId(), dt1, dt2);
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
            if (BusinessHours.isWithin(getBusinessHoursId(), slaDate)) {
                businessDaysAdded++;
            }
        }

        return slaDate;
    }
}

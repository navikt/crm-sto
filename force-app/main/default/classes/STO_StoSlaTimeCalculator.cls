global without sharing class STO_StoSlaTimeCalculator implements Support.MilestoneTriggerTimeCalculator {
    private BusinessHours STO_BUSINESS_HOURS = [SELECT Id FROM BusinessHours WHERE Name = 'STO Business Hours'];
    private TimeZone osloTimezone = TimeZone.getTimeZone('Europe/Oslo');

    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {
        Date slaDate = AddBusinessDays(System.today(), 2);
        Datetime endOfSlaDate = Datetime.newInstance(slaDate, Time.newInstance(23, 59, 59, 59));
        return getMinutesBetween(slaDate, Datetime.now());
    }

    /**
     * @description: Calculates the number of minutes between two datetimes relative to the business hours
     * @author Stian Ruud Schikora | 11-18-2021
     * @param dt1
     * @param dt2
     * @return Integer
     **/
    private Integer getMinutesBetween(Datetime dt1, Datetime dt2) {
        Long msBetween = BusinessHours.diff(STO_BUSINESS_HOURS.Id, dt1, dt2);
        msBetween += osloTimezone.getOffset(dt2); //Handling the timezone offset in the SLA calculation
        Integer secondsBetween = msBetween < 0
            ? Integer.valueOf(-1 * msBetween / 1000)
            : Integer.valueOf(msBetween / 1000);
        return secondsBetween / 60;
    }

    /**
     * @description: Adds a given number of business days to a startdate following the STO business hours
     * @author Stian Ruud Schikora | 11-18-2021
     * @param startDate
     * @param businessDaysToAdd
     * @return Date
     **/
    public Date AddBusinessDays(Date startDate, Integer businessDaysToAdd) {
        Date slaDate = startDate;

        Integer businessDaysAdded = 0;
        while (businessDaysAdded <= businessDaysToAdd) {
            slaDate = slaDate.addDays(1);
            if (BusinessHours.isWithin(STO_BUSINESS_HOURS.id, slaDate)) {
                businessDaysAdded++;
            }
        }

        return slaDate;
    }
}

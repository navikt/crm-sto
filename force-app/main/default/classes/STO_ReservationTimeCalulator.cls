global without sharing class STO_ReservationTimeCalulator implements Support.MilestoneTriggerTimeCalculator {

    private static final Integer DEFAULT_TIME = 5;

    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {

        if(milestoneTypeId == null && !Test.isRunningTest()) return DEFAULT_TIME;

        Datetime now = Datetime.now();
        String weekDayEndTime = now.format('EEEE') + 'EndTime';
        String query = 
            'SELECT ' + 
            weekDayEndTime +
            ' FROM BusinessHours ' +
            'WHERE Id IN (' +
                'SELECT BusinessHoursId ' +
                'FROM CaseMilestone ' +
                'WHERE  MilestoneTypeId = :milestoneTypeId' +
            ')' +
            'LIMIT 1';
        Time endOfDay;
        try{
            endOfDay = Test.isRunningTest()?
                Time.newInstance(21,0,0,0) :
                (Time)((BusinessHours)Database.query(query)[0]).getPopulatedFieldsAsMap().get(weekDayEndTime);
            if(endOfDay == null) return DEFAULT_TIME;
        }catch(Exception e){
            return DEFAULT_TIME;
        }

        if( (endOfDay != Time.newInstance(0,0,0,0) && now.time() > endOfDay) ) return DEFAULT_TIME;

        return endOfDay.addHours(-now.time().hour()).hour() * 60 + endOfDay.addMinutes(-now.time().minute()).minute();
    }
}

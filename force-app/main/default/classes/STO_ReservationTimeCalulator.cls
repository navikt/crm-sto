global without sharing class STO_ReservationTimeCalulator implements Support.MilestoneTriggerTimeCalculator {

    private static final Integer DEFAULT_TIME = 5;

    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {

        if(milestoneTypeId == null) return DEFAULT_TIME;

        Datetime now = Datetime.now();
        Datetime nextStartDate;
        BusinessHours bh;
        try{
                String query = 
                    'SELECT Id ' +
                    'FROM BusinessHours ' +
                    'WHERE Id IN (' +
                        'SELECT BusinessHoursId ' +
                        'FROM CaseMilestone ' +
                        'WHERE  MilestoneTypeId = :milestoneTypeId' +
                    ') ' +
                    'LIMIT 1';
                bh = ((BusinessHours)Database.query(query)[0]);
        }catch(Exception e){
            return DEFAULT_TIME;
        }
        nextStartDate = BusinessHours.nextStartDate(
                    bh.Id,
                    Datetime.newInstance(
                        now.date().addDays(1),
                        Time.newInstance(0,0,0,0)
                    )
        );
        Long diff = BusinessHours.diff(bh.Id, now, nextStartDate);
        return (diff /1000 /60).intValue();
    }
}

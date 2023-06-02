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

    /**
     * Description: Calculates time from CaseMilestone StartDate until Violation Action triggers for "Handling Time" Milestone
     *
     */
    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {
        CaseMilestone caseMilestone;
        try {
            caseMilestone = [
                SELECT Id, TargetResponseInMins
                FROM CaseMilestone
                WHERE CaseId = :caseId AND MilestoneType.Name = 'Handling Time' AND IsCompleted = FALSE
                LIMIT 1
            ];
        } catch (Exception ex) {
            // No existing milestone
        }

        // Do not recalculate if Casemilestone already exists.
        // Otherwise it will increment the time, because StartDate remains the same and we are calculating minutes from CaseMilestone StartDate.
        if (caseMilestone?.TargetResponseInMins != null) {
            return caseMilestone.TargetResponseInMins;
        }

        Datetime nextStartDate = BusinessHours.nextStartDate(
            STO_BUSINESS_HOURS_ID,
            Datetime.newInstance(Datetime.now().date().addDays(1), Time.newInstance(0, 0, 0, 0))
        );
        Long diff = BusinessHours.diff(STO_BUSINESS_HOURS_ID, Datetime.now(), nextStartDate);
        return (diff / 1000 / 60).intValue();
    }
}

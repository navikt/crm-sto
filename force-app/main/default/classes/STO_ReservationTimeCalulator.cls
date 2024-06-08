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
     * Description: Calculates the time trigger for the "Handling Time" Milestone (the amount of time in which the Milestone must be completed).
     * Violation Actions on the Milestone settings will escalate and redistribute the case after 2 days if Milestone IsCompleted = FALSE.
     * TargetResponseInMins field: The time to complete the Milestone in minutes.
     * Runs on Case update/insert when Milestone criteria are met.
     */
    global Integer calculateMilestoneTriggerTime(String caseId, String milestoneTypeId) {
        CaseMilestone milestoneCase;
        try {
            milestoneCase = [
                SELECT Id, TargetResponseInMins
                FROM CaseMilestone
                WHERE CaseId = :caseId AND MilestoneType.Name = 'Handling Time' AND IsCompleted = FALSE
                LIMIT 1
            ];
        } catch (Exception e) {
            // No existing Milestone
        }

        // Do not recalculate if CaseMilestone already exists.
        if (milestoneCase?.TargetResponseInMins != null) {
            return milestoneCase.TargetResponseInMins;
        }

        // nextStartDate method: Starting from the specified target date, returns the next date when business hours are open.
        // If the specified target date falls within business hours, this target date is returned.
        Datetime nextStartDate = BusinessHours.nextStartDate(
            STO_BUSINESS_HOURS_ID,
            Datetime.newInstance(Datetime.now().date().addDays(1), Time.newInstance(0, 0, 0, 0))
        );
        Long diff = BusinessHours.diff(STO_BUSINESS_HOURS_ID, Datetime.now(), nextStartDate);
        Long diff = BusinessHours.diff(STO_BUSINESS_HOURS_ID, Datetime.now(), nextStartDate);
        Intenger diffTime = (diff / 1000 / 60).intValue();
        if(diffTime < 1) {
            return 1;
        }
        return diffTime;
    }
    }
}

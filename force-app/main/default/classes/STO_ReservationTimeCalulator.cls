global without sharing class STO_ReservationTimeCalulator implements Support.MilestoneTriggerTimeCalculator {
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
            getBusinessHoursId(),
            Datetime.newInstance(Datetime.now().date().addDays(1), Time.newInstance(0, 0, 0, 0))
        );
        Long diff = BusinessHours.diff(getBusinessHoursId(), Datetime.now(), nextStartDate);
        Integer diffTime = (diff / 1000 / 60).intValue();
        if (diffTime < 1) {
            return 1;
        }
        return diffTime;
    }
}

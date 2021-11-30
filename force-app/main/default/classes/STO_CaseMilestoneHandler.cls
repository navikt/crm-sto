global without sharing class STO_CaseMilestoneHandler extends MyTriggers {
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String HANDLING_TIME_TYPE_NAME = 'Handling Time';
    private static final Set<String> milestoneTypes = new Set<String>{ RESPOND_STO_TYPE_NAME, HANDLING_TIME_TYPE_NAME };
    private static final Set<String> triggerStatuses = new Set<String>{ 'On Hold', 'Forwarded', 'Closed' };

    global override void onBeforeUpdate(Map<Id, sObject> triggerOldMap) {
        List<String> fieldNamesToCheck = new List<String>{ 'Status' };
        Map<Id, Case> casesToHandle = new Map<Id, Case>();

        for (Case casy : (List<Case>) Trigger.new) {
            Case oldRecord = (Case) triggerOldMap.get(casy.Id);
            if (
                casy.Origin == 'STO' &&
                triggerStatuses.contains(casy.Status) &&
                MyTriggers.hasChangedFields(fieldNamesToCheck, casy, oldRecord)
            ) {
                casesToHandle.put(casy.Id, casy);
            }
        }

        closeCaseMilestones(casesToHandle);
    }

    private void closeCaseMilestones(Map<Id, Case> casesToHandle) {
        Datetime complTime = Datetime.now();
        List<CaseMilestone> milestoneList = [
            SELECT Id, CaseId, MilestoneType.Name
            FROM CaseMilestone
            WHERE CaseId IN :casesToHandle.keySet() AND IsCompleted = FALSE AND MilestoneType.Name IN :milestoneTypes
        ];
        for (CaseMilestone caseMile : milestoneList) {
            Case milestoneCase = casesToHandle.get(caseMile.CaseId);
            if (milestoneCase.Status == 'Forwarded') {
                //Only close handling time milestone, response time is still initial as end user is still awaiting the "full" response
                caseMile.CompletionDate = caseMile.MilestoneType.Name == 'Respond STO' ? null : complTime;
            } else {
                caseMile.CompletionDate = complTime;
            }
        }

        update milestoneList;
    }
}

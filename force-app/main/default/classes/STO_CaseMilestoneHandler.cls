global without sharing class STO_CaseMilestoneHandler extends MyTriggers {
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String HANDLING_TIME_TYPE_NAME = 'Handling Time';
    private static final Set<String> milestoneTypes = new Set<String>{ RESPOND_STO_TYPE_NAME, HANDLING_TIME_TYPE_NAME };

    global override void onBeforeUpdate(Map<Id, sObject> triggerOldMap) {
        List<String> fieldNamesToCheck = new List<String>{ 'Status' };
        Set<Id> casesToHandle = new Set<Id>();

        for (Case casy : (List<Case>) Trigger.new) {
            Case oldRecord = (Case) triggerOldMap.get(casy.Id);
            if (
                casy.Origin == 'STO' &&
                casy.Status == 'On Hold' &&
                MyTriggers.hasChangedFields(fieldNamesToCheck, casy, oldRecord)
            ) {
                casesToHandle.add(casy.Id);
            }
        }

        closeCaseMilestones(casesToHandle);
    }

    private void closeCaseMilestones(Set<Id> caseIds) {
        Datetime complTime = Datetime.now();
        List<CaseMilestone> milestoneList = [
            SELECT Id
            FROM CaseMilestone
            WHERE CaseId IN :caseIds AND IsCompleted = FALSE AND MilestoneType.Name IN :milestoneTypes
        ];
        for (CaseMilestone caseMile : milestoneList) {
            caseMile.CompletionDate = complTime;
        }

        update milestoneList;
    }
}

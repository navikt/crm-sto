global without sharing class STO_CaseMilestoneHandler extends MyTriggers {
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String RESPOND_BTO_TYPE_NAME = 'Respond BTO';
    private static final String HANDLING_TIME_TYPE_NAME = 'Handling Time';
    private static final Set<String> milestoneTypes = new Set<String>{
        RESPOND_STO_TYPE_NAME,
        RESPOND_BTO_TYPE_NAME,
        HANDLING_TIME_TYPE_NAME
    };
    private static final Set<String> triggerStatuses = new Set<String>{ 'On Hold', 'Forwarded', 'Closed' };
    private static LoggerUtility logger = new LoggerUtility('STO/BTO Milestones');
    private static final CRM_ApplicationDomain.Domain domain = CRM_ApplicationDomain.Domain.NKS;

    global override void onBeforeUpdate(Map<Id, sObject> triggerOldMap) {
        List<String> fieldNamesToCheck = new List<String>{ 'Status' };
        Map<Id, Case> casesToHandle = new Map<Id, Case>();

        for (Case casy : (List<Case>) Trigger.new) {
            Case oldCaseRecord = (Case) triggerOldMap.get(casy.Id);
            if (
                casy.Origin == 'STO' ||
                casy.origin == 'BTO' && triggerStatuses.contains(casy.Status) &&
                MyTriggers.hasChangedFields(fieldNamesToCheck, casy, oldCaseRecord)
            ) {
                casesToHandle.put(casy.Id, casy);
            }
        }
        closeCaseMilestones(casesToHandle);
    }

    private void closeCaseMilestones(Map<Id, Case> casesToHandle) {
        Datetime completionTime = Datetime.now();
        List<ReportingData__c> repDataList = new List<ReportingData__c>();
        List<CaseMilestone> milestoneList = Test.isRunningTest()
            ? new List<CaseMilestone>{ new CaseMilestone() }
            : [
                  SELECT Id, CaseId, MilestoneType.Name
                  FROM CaseMilestone
                  WHERE
                      CaseId IN :casesToHandle.keySet()
                      AND IsCompleted = FALSE
                      AND MilestoneType.Name IN :milestoneTypes
              ];
        for (CaseMilestone milestoneCase : milestoneList) {
            Case casy = casesToHandle.containsKey(milestoneCase.CaseId)
                ? casesToHandle.get(milestoneCase.CaseId)
                : null;

            if (
                // Do not close "Respond STO/BTO" Milestone as Case is not resolved yet when Status = "Forwarded"
                casy != null &&
                casy.Status == 'Forwarded' &&
                milestoneCase.MilestoneType.Name == HANDLING_TIME_TYPE_NAME
            ) {
                milestoneCase.CompletionDate = completionTime;
            } else {
                if (!Test.isRunningTest())
                    milestoneCase.CompletionDate = completionTime;
            }

            if (milestoneCase.CompletionDate != null || Test.isRunningTest()) {
                repDataList.add(
                    new ReportingData__c(
                        CRM_Category__c = casy?.Origin,
                        STO_Category__c = casy?.STO_Category__c,
                        STO_MilestoneId__c = milestoneCase.Id,
                        CRM_NavUnitNumber__c = casy?.STO_Owner_Department__c
                    )
                );
            }
        }

        if (!repDataList.isEmpty())
            handleReportingData(repDataList);

        if (!Test.isRunningTest())
            update milestoneList;
    }

    private static void handleReportingData(List<ReportingData__c> repDataList) {
        try {
            insert repDataList;
        } catch (Exception ex) {
            logger.critical(JSON.serializePretty(repDataList), null, domain);
        } finally {
            logger.publish();
        }
    }
}

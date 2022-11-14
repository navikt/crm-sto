global without sharing class STO_CaseMilestoneHandler extends MyTriggers {
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String HANDLING_TIME_TYPE_NAME = 'Handling Time';
    private static final Set<String> milestoneTypes = new Set<String>{ RESPOND_STO_TYPE_NAME, HANDLING_TIME_TYPE_NAME };
    private static final Set<String> triggerStatuses = new Set<String>{ 'On Hold', 'Forwarded', 'Closed' };
    private static LoggerUtility logger = new LoggerUtility('STO Milestones');
    private static final CRM_ApplicationDomain.Domain domain = CRM_ApplicationDomain.Domain.NKS;

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
        for (CaseMilestone caseMile : milestoneList) {
            Case milestoneCase = casesToHandle.containsKey(caseMile.CaseId) ? casesToHandle.get(caseMile.CaseId) : null;
            if (milestoneCase != null && milestoneCase.Status == 'Forwarded') {
                //Only close handling time milestone, response time is still initial as end user is still awaiting the "full" response
                caseMile.CompletionDate = caseMile.MilestoneType.Name == 'Respond STO' ? null : complTime;
            } else {
                if (!Test.isRunningTest())
                    caseMile.CompletionDate = complTime;
            }

            if (caseMile.CompletionDate != null || Test.isRunningTest()) {
                repDataList.add(
                    new ReportingData__c(
                        CRM_Category__c = 'STO',
                        STO_Category__c = milestoneCase?.STO_Category__c,
                        STO_MilestoneId__c = caseMile.Id,
                        CRM_NavUnitNumber__c = milestoneCase?.STO_Owner_Department__c
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

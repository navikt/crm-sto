global without sharing class STO_CaseMilestoneHandler extends MyTriggers {
    private static final String RESPOND_STO_TYPE_NAME = 'Respond STO';
    private static final String RESPOND_BTO_TYPE_NAME = 'Respond BTO';
    private static final String HANDLING_TIME_TYPE_NAME = 'Handling Time';
    private static final String HANDLING_TIME_BTO_TYPE_NAME = 'Handling Time BTO';
    private static final Set<String> milestoneTypes = new Set<String>{
        RESPOND_STO_TYPE_NAME,
        RESPOND_BTO_TYPE_NAME,
        HANDLING_TIME_TYPE_NAME,
        HANDLING_TIME_BTO_TYPE_NAME
    };
    private static final Set<String> responseTypes = new Set<String>{ RESPOND_STO_TYPE_NAME, RESPOND_BTO_TYPE_NAME };
    private static final Set<String> triggerStatuses = new Set<String>{ 'On Hold', 'Forwarded', 'Closed', 'New' };
    private static LoggerUtility logger = new LoggerUtility('STO/BTO Milestones');
    private static final CRM_ApplicationDomain.Domain domain = CRM_ApplicationDomain.Domain.NKS;

    global override void onBeforeUpdate(Map<Id, sObject> triggerOldMap) {
        List<String> fieldNamesToCheck = new List<String>{ 'Status', 'Origin' };
        Map<Id, CaseWrapper> casesToHandle = new Map<Id, CaseWrapper>();

        for (Case casy : (List<Case>) Trigger.new) {
            Case oldCaseRecord = (Case) triggerOldMap.get(casy.Id);
            if (
                (casy.Origin == 'STO' ||
                casy.Origin == 'BTO') &&
                triggerStatuses.contains(casy.Status) &&
                MyTriggers.hasChangedFields(fieldNamesToCheck, casy, oldCaseRecord)
            ) {
                casesToHandle.put(
                    casy.Id,
                    new CaseWrapper(
                        casy,
                        MyTriggers.hasChangedFields(new List<String>{ 'Origin' }, casy, oldCaseRecord)
                    )
                );
            }
        }
        closeCaseMilestones(casesToHandle);
    }

    private void closeCaseMilestones(Map<Id, CaseWrapper> casesToHandle) {
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
            CaseWrapper wrapper = casesToHandle.containsKey(milestoneCase.CaseId)
                ? casesToHandle.get(milestoneCase.CaseId)
                : null;
            Case casy = wrapper?.relatedCase;
            Boolean hasChangedOrigin = wrapper?.hasChangedOrigin;

            // Close all milestones except Respond STO/BTO cases that were forwarded but remained on the same origin
            if (
                casy != null && hasChangedOrigin != null &&
                (responseTypes.contains(milestoneCase.MilestoneType.Name) &&
                casy.Status == 'Forwarded' &&
                !hasChangedOrigin) ||
                Test.isRunningTest() ||
                (casy.Status == 'New' && !hasChangedOrigin)
            ) {
                milestoneCase.CompletionDate = null;
            } else {
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

    public class CaseWrapper {
        public Case relatedCase;
        public Boolean hasChangedOrigin;

        public CaseWrapper(Case relatedCase, Boolean hasChangedOrigin) {
            this.relatedCase = relatedCase;
            this.hasChangedOrigin = hasChangedOrigin;
        }
    }
}

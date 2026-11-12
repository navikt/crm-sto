/**
 * @description       :
 * @author            : mamikals
 * @group             :
 * @last modified on  : 07-06-2026
 * @last modified by  : Sara Mohammadi
 **/
public without sharing class nksGetStoUtilityController {
    @TestVisible
    private static LoggerUtility logger = new LoggerUtility('GET_STO');
    private final static Integer MAX_ATTEMPTS = 5;
    private static final Long SLOW_EXECUTION_THRESHOLD_MS = 10000;
    private static ExecutionTiming executionTiming;

    @TestVisible
    private class ExecutionTiming {
        private String methodName;
        @TestVisible
        private Long executionStartedAt = System.now().getTime();
        @TestVisible
        private Long currentStepStartedAt = executionStartedAt;
        private String currentStepName;
        private Boolean isCurrentStepQuery = false;
        private Long queryDurationMs = 0;
        private List<Map<String, Object>> completedSteps = new List<Map<String, Object>>();

        public ExecutionTiming(String methodName) {
            this.methodName = methodName;
        }

        public void startStep(String nextStepName, Boolean isNextStepQuery) {
            Long stepTransitionAt = System.now().getTime();
            completeCurrentStep(stepTransitionAt);
            currentStepName = nextStepName;
            isCurrentStepQuery = isNextStepQuery;
            currentStepStartedAt = stepTransitionAt;
        }

        private void completeCurrentStep(Long currentStepEndedAt) {
            if (currentStepName != null) {
                Long completedStepDurationMs = currentStepEndedAt - currentStepStartedAt;
                completedSteps.add(
                    new Map<String, Object>{ 'step' => currentStepName, 'durationMs' => completedStepDurationMs }
                );
                if (isCurrentStepQuery) {
                    queryDurationMs += completedStepDurationMs;
                }
                currentStepName = null;
            }
        }

        public void logExecution(Long executionEndedAt) {
            completeCurrentStep(executionEndedAt);
            Long durationMs = executionEndedAt - executionStartedAt;
            Boolean isSlow = durationMs > SLOW_EXECUTION_THRESHOLD_MS;
            logger.logMessage(
                isSlow ? LoggerUtility.LogLevel.WARNING : LoggerUtility.LogLevel.INFO,
                null,
                null,
                methodName + ' took ' + durationMs + ' ms; queries took ' + queryDurationMs + ' ms',
                isSlow ? JSON.serialize(completedSteps) : null,
                durationMs,
                CRM_ApplicationDomain.Domain.NKS
            );
        }
    }

    private static void startTimingStep(String nextStepName, Boolean isNextStepQuery) {
        if (executionTiming != null) {
            executionTiming.startStep(nextStepName, isNextStepQuery);
        }
    }

    public class TooManyAttemptsException extends Exception {
    }
    public class NoCasesFoundException extends Exception {
    }

    private static final List<String> additionalSkills = new List<String>{
        'Fortrolig_addresse',
        'Skjermede_personer',
        'Serviceklage'
    };
    private static final List<String> originSkills = new List<String>{ 'BTO', 'STO' };

    private static final Map<String, String> stoThemeRenames = new Map<String, String>{ 'Ufør' => 'Ufoeretrygd' };

    private static List<String> cachedRelevantSkills;

    // Since Omni channel skills are org based, we want to only include skills that are used in STO
    public static final List<String> allRelevantSkills {
        get {
            if (cachedRelevantSkills != null) {
                return cachedRelevantSkills;
            }
            Schema.DescribeFieldResult fieldResult = Case.STO_Category__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            List<String> skills = new List<String>();
            for (Schema.PicklistEntry pl : ple) {
                if (stoThemeRenames.containsKey(pl.getLabel())) {
                    skills.add(stoThemeRenames.get(pl.getLabel()));
                } else {
                    skills.add(pl.getLabel());
                }
            }
            skills.addAll(additionalSkills);
            skills.addAll(originSkills);
            cachedRelevantSkills = skills;
            return cachedRelevantSkills;
        }
    }

    private static Id filteredSkillId;

    private static GroupedSkills allUserSkills = new GroupedSkills();

    @AuraEnabled
    public static List<Record> getStoWithSkill(Id skillId) {
        filteredSkillId = skillId;
        return getSto('getStoWithSkill');
    }

    @AuraEnabled
    public static List<Record> getSto() {
        return getSto('getSto');
    }

    private static List<Record> getSto(String methodName) {
        executionTiming = new ExecutionTiming(methodName);
        try {
            return fetchSto();
        } finally {
            ExecutionTiming completedTiming = executionTiming;
            executionTiming = null;
            completedTiming.logExecution(System.now().getTime());
            logger.publish();
        }
    }

    private static List<Record> fetchSto() {
        List<Record> records = new List<Record>();
        startTimingStep('hasInProgress', true);
        if (hasInProgress()) {
            throw new AuraHandledException('hasInProgress');
        }

        startTimingStep('getNewSTO.prepare', false);
        Record newStoRecord = new Record();
        newStoRecord.recordId = getNewSTO();
        newStoRecord.status = 'In Progress';
        records.add(newStoRecord);
        Set<Id> relatedStoIds = new Set<Id>();
        try {
            startTimingStep('getRelatedSTO.flow', false);
            relatedStoIds.addAll(getRelatedSTO(newStoRecord.recordId));
        } catch (Exception e) {
            // exception on finding related stos
        }
        startTimingStep('getSto.buildRecords', false);
        for (Id relatedStoId : relatedStoIds) {
            Record relatedStoRecord = new Record();
            relatedStoRecord.recordId = relatedStoId;
            relatedStoRecord.status = 'Reserved';
            records.add(relatedStoRecord);
        }
        return records;
    }

    @AuraEnabled
    public static Id getNewSTO() {
        try {
            Integer attempt = 0;
            Id userId = getCurrentUserId();
            startTimingStep('getServiceResourceSkillIds.prepare', false);
            allUserSkills = getServiceResourceSkillIds();

            do {
                startTimingStep('getNewSTO.attempt.' + (attempt + 1), false);
                Id nextCaseId = getNextSTOCase();
                if (takeOwnership(nextCaseId, userId)) {
                    return nextCaseId;
                }
                attempt += 1;
            } while (attempt < MAX_ATTEMPTS);
            throw new TooManyAttemptsException('Max Attempt Count Exceeded: ' + MAX_ATTEMPTS);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Boolean takeOwnership(Id caseId, Id userId) {
        try {
            startTimingStep('takeOwnership.lockQuery', true);
            Case c = [SELECT Id, OwnerId, Owner.Type, Status FROM Case WHERE Id = :caseId LIMIT 1 FOR UPDATE];
            startTimingStep('takeOwnership.checkOwner', false);
            if (c.Owner.Type != 'Queue') {
                return false;
            }
            c.OwnerId = userId;
            c.Status = 'In progress';
            startTimingStep('takeOwnership.update', false);
            update c;
        } catch (Exception e) {
            return false;
        }
        return true;
    }

    @AuraEnabled
    public static List<Id> getRelatedSTO(Id caseId) {
        List<Id> relatedCaseIds = new List<Id>();
        try {
            Map<String, Object> flowParams = new Map<String, Object>();
            flowParams.put('CaseId', caseId);
            flowParams.put(
                'HasServiceklageSkill',
                allUserSkills.additionalSkillsBySkillId.values().contains('Serviceklage')
            );
            if (Test.isRunningTest()) {
                allUserSkills.originSkillsBySkillId.put('001xa000003DIlo', 'STO');
            }
            flowParams.put('UserOriginSkills', allUserSkills.originSkillsBySkillId.values());

            Flow.Interview.STO_Case_Set_Owner setOwnerFlow = new Flow.Interview.STO_Case_Set_Owner(flowParams);
            setOwnerFlow.start();
            List<Case> relatedCases = (List<Case>) setOwnerFlow.getVariableValue('ReturnVar');
            if (relatedCases == null) {
                return relatedCaseIds;
            }
            for (Case c : relatedCases) {
                relatedCaseIds.add(c.Id);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return relatedCaseIds;
    }

    @AuraEnabled(cacheable=true)
    public static GroupedSkills getServiceResourceSkillIds() {
        Id userId = getCurrentUserId();
        GroupedSkills userSkills = new GroupedSkills();
        Datetime nowDt = System.now();
        // Fetch the skills before querying SRS so the don't affect the step timing
        List<String> relevantSkills = allRelevantSkills;

        startTimingStep('getServiceResourceSkillIds.query', true);
        List<ServiceResourceSkill> resourceSkills = [
            SELECT SkillId, Skill.DeveloperName, Skill.MasterLabel
            FROM ServiceResourceSkill
            WHERE
                ServiceResource.RelatedRecordId = :userId
                AND Skill.DeveloperName IN :relevantSkills
                AND EffectiveStartDate <= :nowDt
                AND (EffectiveEndDate = NULL
                OR EffectiveEndDate >= :nowDt)
                AND ServiceResource.IsActive = TRUE
        ];
        startTimingStep('getServiceResourceSkillIds.groupSkills', false);
        for (ServiceResourceSkill srs : resourceSkills) {
            //Separating domain skills and person access skills
            if (additionalSkills.contains(srs.Skill.DeveloperName)) {
                userSkills.additionalSkillsBySkillId.put(srs.SkillId, srs.Skill.DeveloperName);
            } else if (originSkills.contains(srs.Skill.DeveloperName)) {
                userSkills.originSkillsBySkillId.put(srs.SkillId, srs.Skill.DeveloperName);
            } else {
                if (filteredSkillId == null || filteredSkillId == srs.SkillId) {
                    userSkills.skillMap.put(srs.SkillId, srs.Skill.DeveloperName);
                }
            }
        }
        return userSkills;
    }

    private static Id getNextSTOCase() {
        try {
            List<PendingServiceRouting> psr = getPendingServiceRouting();

            if (psr.size() == 0) {
                throw new NoCasesFoundException('NotFound');
            }
            startTimingStep('getNextSTOCase.checkStatus', false);
            if (psr[0].workItem.Status == 'Closed') {
                startTimingStep('getNextSTOCase.closedCaseQuery', true);
                PendingServiceRouting psrToLog = [
                    SELECT Id, WorkItemId, WorkItem.Status, CreatedDate, CreatedBy.Name, IsPushed, OwnerId
                    FROM PendingServiceRouting
                    WHERE Id = :psr[0].Id
                    LIMIT 1
                ];
                startTimingStep('getNextSTOCase.logClosedCase', false);
                logger.error('PSR pushed where STO Case is status closed.', psrToLog, CRM_ApplicationDomain.Domain.NKS);
                logger.publish();
            }
            return psr[0].WorkItemId;
        } catch (QueryException queryEx) {
            throw new AuraHandledException('En feil oppsto ved henting av ny STO, prøv igjen.');
        }
    }

    /**
     * Queries the PSR with highest priority within your skill pool and ensures you have access to the person,
     * that the case relates to
     * @author Stian Ruud Schikora | 07-19-2022
     * @return List<PendingServiceRouting>
     **/
    private static List<PendingServiceRouting> getPendingServiceRouting() {
        String userId = getCurrentUserId();

        Set<Id> includedPSRIds = new Set<Id>();
        startTimingStep('getPendingServiceRouting.includedSkillsQuery', true);
        List<SkillRequirement> includedRequirements = [
            SELECT RelatedRecordId
            FROM SkillRequirement
            WHERE SkillId IN :allUserSkills.skillMap.keySet()
        ];
        startTimingStep('getPendingServiceRouting.collectIncludedIds', false);
        for (SkillRequirement sr : includedRequirements) {
            includedPSRIds.add(sr.RelatedRecordId);
        }

        Set<Id> excludedPSRIds = new Set<Id>();
        startTimingStep('getPendingServiceRouting.excludedSkillsQuery', true);
        List<SkillRequirement> excludedRequirements = [
            SELECT RelatedRecordId
            FROM SkillRequirement
            WHERE
                (Skill.DeveloperName IN :additionalSkills
                AND Skill.DeveloperName NOT IN :allUserSkills.additionalSkillsBySkillId.values())
                OR (Skill.DeveloperName IN :originSkills
                AND Skill.DeveloperName NOT IN :allUserSkills.originSkillsBySkillId.values())
        ];
        startTimingStep('getPendingServiceRouting.collectExcludedIds', false);
        for (SkillRequirement sr : excludedRequirements) {
            excludedPSRIds.add(sr.RelatedRecordId);
        }

        startTimingStep('getPendingServiceRouting.candidatesQuery', true);
        List<PendingServiceRouting> allCandidates = [
            SELECT Id, WorkItemId, WorkItem.NKS_Incompetent_IDs__c, WorkItem.Status
            FROM PendingServiceRouting
            WHERE
                ServiceChannel.DeveloperName = 'Skriv_til_oss'
                AND IsReadyForRouting = TRUE
                AND isPushed = FALSE
                AND Id IN :includedPSRIds
            ORDER BY RoutingPriority, SecondaryRoutingPriority DESC NULLS LAST, CreatedDate
        ];

        startTimingStep('getPendingServiceRouting.filterCandidates', false);
        for (PendingServiceRouting psr : allCandidates) {
            // Skip if user lacks required confidentiality/origin skills
            if (excludedPSRIds.contains(psr.Id)) {
                continue;
            }

            // Skip if user is in the incompetent list
            if (
                String.isNotBlank(psr.WorkItem.NKS_Incompetent_IDs__c) &&
                psr.WorkItem.NKS_Incompetent_IDs__c.contains(userId)
            ) {
                continue;
            }

            // Return first valid PSR
            return new List<PendingServiceRouting>{ psr };
        }

        return new List<PendingServiceRouting>();
    }

    public class GroupedSkills {
        @AuraEnabled
        public Map<Id, String> skillMap = new Map<Id, String>();
        @AuraEnabled
        public Map<Id, String> additionalSkillsBySkillId = new Map<Id, String>();
        @AuraEnabled
        public Map<Id, String> originSkillsBySkillId = new Map<Id, String>();
    }

    private static Id cachedUserId;
    private static Id getCurrentUserId() {
        if (cachedUserId == null) {
            cachedUserId = UserInfo.getUserId();
        }
        return cachedUserId;
    }

    // Cache RecordTypeId to avoid repeated queries
    private static Id stoRecordTypeId;

    private static Id getSTORecordTypeId() {
        if (stoRecordTypeId == null) {
            stoRecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get('STO_Case')
                .getRecordTypeId();
        }
        return stoRecordTypeId;
    }

    @AuraEnabled(cacheable=true)
    public static List<Record> getList() {
        Id recordTypeId = getSTORecordTypeId();
        List<Case> listtoreturn = [
            SELECT CreatedDate, toLabel(Status), STO_Category__c, CaseNumber
            FROM Case
            WHERE
                Status IN ('New', 'In progress', 'Reserved')
                AND RecordTypeId = :recordTypeId
                AND OwnerId = :getCurrentUserId()
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        return createRecords(listtoreturn);
    }

    private static Boolean hasInProgress() {
        List<Case> casesInProgress = [
            SELECT Id
            FROM Case
            WHERE
                Status IN ('New', 'In progress')
                AND RecordTypeId = :getSTORecordTypeId()
                AND OwnerId = :getCurrentUserId()
            LIMIT 1
        ];
        return casesInProgress.size() > 0;
    }

    public class Record {
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Datetime modifiedDate;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String casenumber;
    }

    private static List<Record> createRecords(List<Case> listofrecords) {
        List<Record> records = new List<Record>();
        for (Case r : listofrecords) {
            Record record = new Record();
            record.recordId = r.Id;
            record.name = r.STO_Category__c;
            record.modifiedDate = Datetime.valueOf(r.CreatedDate);
            record.status = r.Status;
            record.casenumber = r.CaseNumber;
            records.add(record);
        }
        return records;
    }
}

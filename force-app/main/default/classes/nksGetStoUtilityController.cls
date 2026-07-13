/**
 * @description       :
 * @author            : mamikals
 * @group             :
 * @last modified on  : 07-06-2026
 * @last modified by  : Sara Mohammadi
 **/
public without sharing class nksGetStoUtilityController {
    private static LoggerUtility logger = new LoggerUtility('GET_STO');
    private final static Integer MAX_ATTEMPTS = 5;
    public class TooManyAttemptsException extends Exception {
    }
    public class NoCasesFoundException extends Exception {
    }

    private static final List<String> confidentialitySkills = new List<String>{
        'Fortrolig_addresse',
        'Skjermede_personer',
        'Serviceklager'
    };
    private static final String SERVICEKLAGER_SKILL = 'Serviceklager';
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
            skills.addAll(confidentialitySkills);
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
        return getSto();
    }

    @AuraEnabled
    public static List<Record> getSto() {
        List<Record> records = new List<Record>();
        if (hasInProgress())
            throw new AuraHandledException('hasInProgress');

        allUserSkills = getServiceResourceSkillIds();

        Record newStoRecord = new Record();
        Id newStoId = getNewSTO();
        if (newStoId == null) {
            throw new AuraHandledException('NotFound');
        }
        newStoRecord.recordId = newStoId;
        newStoRecord.status = 'In Progress';
        records.add(newStoRecord);

        Set<Id> relatedStoIds = new Set<Id>();
        try {
            relatedStoIds.addAll(getRelatedSTO(newStoRecord.recordId));
        } catch (Exception e) {
            // exception on finding related stos
        }

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
            allUserSkills = getServiceResourceSkillIds();

            do {
                Id nextCaseId = getNextSTOCase();
                if (nextCaseId == null) {
                    attempt += 1;
                    continue;
                }
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
            Case c = [SELECT Id, OwnerId, Owner.Type, Status FROM Case WHERE Id = :caseId LIMIT 1 FOR UPDATE];
            if (c.Owner.Type != 'Queue') {
                return false;
            }
            c.OwnerId = userId;
            c.Status = 'In progress';
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
            if (Test.isRunningTest()) {
                allUserSkills.originSkillsBySkillId.put('001xa000003DIlo', 'STO');
            }
            flowParams.put('UserOriginSkills', allUserSkills.originSkillsBySkillId.values());

            Flow.Interview.STO_Case_Set_Owner setOwnerFlow = new Flow.Interview.STO_Case_Set_Owner(flowParams);
            setOwnerFlow.start();
            List<Case> relatedCases = (List<Case>) setOwnerFlow.getVariableValue('ReturnVar');
            if (relatedCases == null)
                return relatedCaseIds;
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

        for (ServiceResourceSkill srs : [
            SELECT SkillId, Skill.DeveloperName, Skill.MasterLabel
            FROM ServiceResourceSkill
            WHERE
                ServiceResource.RelatedRecordId = :userId
                AND Skill.DeveloperName IN :allRelevantSkills
                AND EffectiveStartDate <= :nowDt
                AND (EffectiveEndDate = NULL
                OR EffectiveEndDate >= :nowDt)
                AND ServiceResource.IsActive = TRUE
        ]) {
            //Separating domain skills and person access skills
            if (confidentialitySkills.contains(srs.Skill.DeveloperName)) {
                userSkills.confidentialitySkillsBySkillId.put(srs.SkillId, srs.Skill.DeveloperName);
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
            if (psr[0].workItem.Status == 'Closed') {
                PendingServiceRouting psrToLog = [
                    SELECT Id, WorkItemId, WorkItem.Status, CreatedDate, CreatedBy.Name, IsPushed, OwnerId
                    FROM PendingServiceRouting
                    WHERE Id = :psr[0].Id
                    LIMIT 1
                ];
                logger.error('PSR pushed where STO Case is status closed.', psrToLog, CRM_ApplicationDomain.Domain.NKS);
                logger.publish();
            }
            return psr[0].WorkItemId;
        } catch (QueryException queryEx) {
            throw new AuraHandledException('En feil oppsto ved henting av ny STO, prøv igjen.');
        }
    }

    /**
     * @description       : Queries the highest-priority PSR in the user's skill pool and enforces
     *                     confidentiality/origin access, incompetent-user exclusion, and serviceklager case restriction.
     * @author Stian Ruud Schikora | 07-19-2022
     * @updated           : 07-06-2026 | Sara Mohammadi | Enforced full per-PSR skill matching and datetime-valid user skills
     * @return List<PendingServiceRouting>
     **/
    private static List<PendingServiceRouting> getPendingServiceRouting() {
        String userId = getCurrentUserId();

        Set<String> userSkillDeveloperNames = new Set<String>();
        userSkillDeveloperNames.addAll(allUserSkills.skillMap.values());
        userSkillDeveloperNames.addAll(allUserSkills.confidentialitySkillsBySkillId.values());
        userSkillDeveloperNames.addAll(allUserSkills.originSkillsBySkillId.values());

        // Candidate PSRs in priority order
        List<PendingServiceRouting> allCandidates = [
            SELECT Id, WorkItemId, WorkItem.NKS_Incompetent_IDs__c, WorkItem.Status
            FROM PendingServiceRouting
            WHERE ServiceChannel.DeveloperName = 'Skriv_til_oss' AND IsReadyForRouting = TRUE AND IsPushed = FALSE
            ORDER BY RoutingPriority, SecondaryRoutingPriority DESC NULLS LAST, CreatedDate
        ];

        if (allCandidates.isEmpty()) {
            return new List<PendingServiceRouting>();
        }

        Set<Id> candidatePsrIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>();
        for (PendingServiceRouting psr : allCandidates) {
            candidatePsrIds.add(psr.Id);
            if (psr.WorkItemId != null) {
                caseIds.add(psr.WorkItemId);
            }
        }

        // Required skills per PSR
        Map<Id, Set<String>> requiredSkillDevNamesByPsrId = new Map<Id, Set<String>>();
        for (SkillRequirement sr : [
            SELECT RelatedRecordId, Skill.DeveloperName
            FROM SkillRequirement
            WHERE RelatedRecordId IN :candidatePsrIds
        ]) {
            if (!requiredSkillDevNamesByPsrId.containsKey(sr.RelatedRecordId)) {
                requiredSkillDevNamesByPsrId.put(sr.RelatedRecordId, new Set<String>());
            }
            requiredSkillDevNamesByPsrId.get(sr.RelatedRecordId).add(sr.Skill.DeveloperName);
        }

        Map<Id, Case> casesById = getCasesByIdsWithServiceklagerFlag(caseIds);

        for (PendingServiceRouting psr : allCandidates) {
            // Skip if user is in the incompetent list
            if (
                String.isNotBlank(psr.WorkItem.NKS_Incompetent_IDs__c) &&
                psr.WorkItem.NKS_Incompetent_IDs__c.contains(userId)
            ) {
                continue;
            }

            // Defensive check against case field
            Case c = casesById.get(psr.WorkItemId);
            if (
                c != null &&
                c.STO_Requires_Serviceklager_Skill__c == true &&
                !userSkillDeveloperNames.contains(SERVICEKLAGER_SKILL)
            ) {
                continue;
            }

            // Enforce ALL required PSR skills:
            // - STO case => requires STO
            // - BTO case => requires BTO
            // - Serviceklager case => requires Serviceklager
            // - Combined cases require all combined skills
            Set<String> required = requiredSkillDevNamesByPsrId.get(psr.Id);
            if (required != null && !required.isEmpty()) {
                Boolean missingSkill = false;
                for (String reqDevName : required) {
                    if (!userSkillDeveloperNames.contains(reqDevName)) {
                        missingSkill = true;
                        break;
                    }
                }
                if (missingSkill) {
                    continue;
                }
            }

            // Return first valid PSR
            return new List<PendingServiceRouting>{ psr };
        }

        return new List<PendingServiceRouting>();
    }

    private static Map<Id, Case> getCasesByIdsWithServiceklagerFlag(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return new Map<Id, Case>();
        }
        return new Map<Id, Case>(
            [
                SELECT Id, STO_Requires_Serviceklager_Skill__c
                FROM Case
                WHERE Id IN :caseIds
            ]
        );
    }

    public class GroupedSkills {
        @AuraEnabled
        public Map<Id, String> skillMap = new Map<Id, String>();
        @AuraEnabled
        public Map<Id, String> confidentialitySkillsBySkillId = new Map<Id, String>();
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

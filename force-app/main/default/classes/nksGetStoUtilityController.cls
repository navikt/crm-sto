public without sharing class nksGetStoUtilityController {
    private final static Integer MAX_ATTEMPTS = 5;
    public class TooManyAttemptsException extends Exception {
    }
    public class NoCasesFoundException extends Exception {
    }

    @AuraEnabled
    public static List<Record> getSto() {
        List<Record> records = new List<Record>();
        if (hasInProgress())
            throw new AuraHandledException('hasInProgress');

        Record newStoRecord = new Record();
        newStoRecord.recordId = getNewSTO();
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
            Id userId = UserInfo.getUserId();
            List<Id> userSkillIds = getServiceResourceSkillIds(userId);
            do {
                Id nextCaseId = getNextSTOCase(userSkillIds);
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
            Flow.Interview.STO_Case_Set_Owner setOwnerFlow = new Flow.Interview.STO_Case_Set_Owner(flowParams);
            setOwnerFlow.start();
            List<Case> relatedCases = (List<Case>) setOwnerFlow.getVariableValue('ReturnVar');
            System.debug(relatedCases);
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

    @AuraEnabled
    public static List<Record> getList(String limitNumber) {
        List<Record> records = new List<Record>();
        List<Case> listtoreturn = [
            SELECT LastModifiedDate, CreatedDate, toLabel(Status), STO_Category__c, CaseNumber
            FROM Case
            WHERE
                Status IN ('New', 'In progress', 'Reserved')
                AND RecordType.DeveloperName = 'STO_Case'
                AND OwnerId = :UserInfo.getUserID()
            ORDER BY CreatedDate DESC
            LIMIT :Integer.valueOf(limitNumber)
        ];
        records = createRecords(listtoreturn);
        return records;
    }

    private static Boolean hasInProgress() {
        List<Case> casesInProgress = [
            SELECT Id
            FROM Case
            WHERE
                Status IN ('New', 'In progress')
                AND RecordType.DeveloperName = 'STO_Case'
                AND OwnerId = :UserInfo.getUserID()
            LIMIT 1
        ];
        return casesInProgress.size() > 0 ? true : false;
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

    @TestVisible
    private static List<Id> getServiceResourceSkillIds(Id userId) {
        List<Id> skillIdList = new List<Id>();
        for (ServiceResourceSkill srs : [
            SELECT SkillId
            FROM ServiceResourceSkill
            WHERE ServiceResource.RelatedRecordId = :userId
        ]) {
            skillIdList.add(srs.SkillId);
        }
        return skillIdList;
    }

    private static Id getNextSTOCase(List<Id> skillIdList) {
        try {
            List<PendingServiceRouting> psr = [
                SELECT Id, WorkItemId
                FROM PendingServiceRouting
                WHERE
                    Id IN (SELECT RelatedRecordId FROM SkillRequirement WHERE SkillId IN :skillIdList)
                    AND WorkitemId IN (
                        SELECT Id
                        FROM Case
                        WHERE RecordType.DeveloperName = 'STO_Case' AND Owner.Type = 'Queue'
                    )
                    AND IsReadyForRouting = TRUE
                    AND isPushed = FALSE
                ORDER BY RoutingPriority, SecondaryRoutingPriority, CreatedDate
                LIMIT 1
            ];
            if (Test.isRunningTest()) {
                return [SELECT Id FROM Case LIMIT 1]?.Id;
            } else if (psr.size() == 0)
                throw new NoCasesFoundException('NotFound');
            return psr[0].WorkItemId;
        } catch (QueryException queryEx) {
            throw new AuraHandledException('En feil oppsto ved henting av ny STO, prøv igjen.');
        }
    }
}

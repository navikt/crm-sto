public with sharing class BTO_AssignBatch implements Database.Batchable<sObject> {
    private static final Map<String, Id> skillMap {
        get {
            List<Skill> skillsToAllocate = [SELECT Id, DeveloperName FROM Skill WHERE DeveloperName IN ('STO', 'BTO')];
            Map<String, Id> retMap = new Map<String, Id>();
            for (Skill skiller : skillsToAllocate) {
                retMap.put(skiller.DeveloperName, skiller.Id);
            }
            return retMap;
        }
    }
    private String profileQuery;

    public BTO_AssignBatch() {
        this.profileQuery = 'NAV Kontaktsenter%';
    }

    public BTO_AssignBatch(String profileQuery) {
        this.profileQuery = profileQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            'Select Id from ServiceResource where Id in (Select ServiceResourceId from ServiceResourceSkill where Skill.DeveloperName in (\'Arbeid\', \'Familie\', \'Helse\', \'Hjelpemidler\', \'Internasjonal\', \'Pensjon\', \'Pleiepenger\', \'Ufoeretrygd\') and (EffectiveEndDate > Today or EffectiveEndDate = null) and EffectiveStartDate <= Today) and RelatedRecord.IsActive = true and RelatedRecord.Profile.Name LIKE :profileQuery'
        );
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<ServiceResourceSkill> newSkillAllocations = new List<ServiceResourceSkill>();
        for (ServiceResource sRes : (List<ServiceResource>) scope) {
            for (Id mappedSkillId : skillMap.values()) {
                newSkillAllocations.add(
                    new ServiceResourceSkill(
                        ServiceResourceId = sRes.Id,
                        SkillLevel = 1,
                        SkillId = mappedSkillId,
                        EffectiveStartDate = Date.today().addDays(-1)
                    )
                );
            }
        }
        insert newSkillAllocations;
    }

    public void finish(Database.BatchableContext BC) {
    }
}

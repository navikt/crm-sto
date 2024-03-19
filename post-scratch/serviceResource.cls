User usr = [SELECT Id FROM User WHERE Name = 'User User'];

// STO Service resource creation.
ServiceResource sr = new ServiceResource(RelatedRecordId = usr.Id, ResourceType = 'A', Name = 'User User', IsActive = true);
insert sr;
List<ServiceResourceSkill> srs = new List<ServiceResourceSkill>();
List<Skill> skills = [Select Id from Skill where DeveloperName in :nksGetStoUtilityController.allRelevantSkills];
Date yesterday = Date.today().addDays(-1);
for(Skill sk : skills) {
    srs.add(new ServiceResourceSkill(EffectiveStartDate = yesterday , ServiceResourceId = sr.Id, SkillId = sk.Id));
}
insert srs;
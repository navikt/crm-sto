System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Utility routing fixtures require a scratch org.'
);
User usr = [SELECT Id, Name FROM User WHERE Name = 'User User' AND IsActive = TRUE AND UserType = 'Standard'];
List<ServiceResource> resources = [
    SELECT Id, IsActive, ResourceType
    FROM ServiceResource
    WHERE RelatedRecordId = :usr.Id
];
System.assert(resources.size() <= 1, 'Expected at most one Service Resource for the scratch agent.');
ServiceResource resource;
if (resources.isEmpty()) {
    resource = new ServiceResource(RelatedRecordId = usr.Id, ResourceType = 'A', Name = usr.Name, IsActive = true);
    insert resource;
} else {
    resource = resources[0];
    if (!resource.IsActive || resource.ResourceType != 'A') {
        resource.IsActive = true;
        resource.ResourceType = 'A';
        update resource;
    }
}

Set<String> missingSkills = new Set<String>(nksGetStoUtilityController.allRelevantSkills);
List<Skill> skills = [SELECT Id, DeveloperName FROM Skill WHERE DeveloperName IN :missingSkills];
for (Skill skill : skills) {
    missingSkills.remove(skill.DeveloperName);
}
System.assert(missingSkills.isEmpty(), 'Deploy the missing routing skills first: ' + missingSkills);
Map<Id, ServiceResourceSkill> assignments = new Map<Id, ServiceResourceSkill>();
for (ServiceResourceSkill assignment : [
    SELECT Id, SkillId, EffectiveStartDate, EffectiveEndDate
    FROM ServiceResourceSkill
    WHERE ServiceResourceId = :resource.Id
    ORDER BY EffectiveStartDate
]) {
    assignments.put(assignment.SkillId, assignment);
}
List<ServiceResourceSkill> assignmentsToInsert = new List<ServiceResourceSkill>();
List<ServiceResourceSkill> assignmentsToUpdate = new List<ServiceResourceSkill>();
Datetime nowDt = System.now();
for (Skill skill : skills) {
    ServiceResourceSkill assignment = assignments.get(skill.Id);
    if (assignment == null) {
        assignmentsToInsert.add(
            new ServiceResourceSkill(
                EffectiveStartDate = nowDt.addDays(-1),
                ServiceResourceId = resource.Id,
                SkillId = skill.Id
            )
        );
    } else if (assignment.EffectiveStartDate > nowDt || assignment.EffectiveEndDate != null) {
        assignment.EffectiveStartDate = nowDt.addDays(-1);
        assignment.EffectiveEndDate = null;
        assignmentsToUpdate.add(assignment);
    }
}
insert assignmentsToInsert;
update assignmentsToUpdate;
System.debug('Scratch utility agent ready. Skills added: ' + assignmentsToInsert.size());

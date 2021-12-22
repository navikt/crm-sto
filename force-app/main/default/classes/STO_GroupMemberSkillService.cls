public with sharing class STO_GroupMemberSkillService {
    private LoggerUtility logger = new LoggerUtility('AD_SKILL_SYNC');
    public static final String FORTOLIG_ADDRESSE_SKILL = 'Fortrolig_addresse';
    public static final String SKJERMEDE_PERSONER_SKILL = 'Skjermede_personer';
    public static final String FORTROLIG_GROUP_NAME = 'Fortrolig_Adresse_AD';
    public static final String SKJERMEDE_GROUP_NAME = 'NKS_Skjermede_Personer_AD';
    private Set<String> groupNamesToSync = new Set<String>{ FORTROLIG_GROUP_NAME, SKJERMEDE_GROUP_NAME };

    private final Map<String, String> groupSkillMap = new Map<String, String>{
        'Fortrolig_Adresse_AD' => FORTOLIG_ADDRESSE_SKILL,
        'NKS_Skjermede_Personer_AD' => SKJERMEDE_PERSONER_SKILL
    };

    @testVisible
    private static Map<Id, User> nksUserMap {
        get {
            if (nksUserMap == null) {
                nksUserMap = new Map<Id, User>();
                for (User usr : [
                    SELECT Id, Name
                    FROM User
                    WHERE
                        Id IN (
                            SELECT AssigneeId
                            FROM PermissionSetAssignment
                            WHERE PermissionSetGroup.DeveloperName = 'Kontaktsenter'
                        )
                ]) {
                    nksUserMap.put(usr.Id, usr);
                }
            }
            return nksUserMap;
        }
        private set {
        }
    }

    @testVisible
    private Map<String, Id> skillIdMap {
        get {
            if (skillIdMap == null) {
                skillIdMap = new Map<String, Id>();
                for (Skill skill : [
                    SELECT Id, DeveloperName
                    FROM Skill
                    WHERE DeveloperName = :FORTOLIG_ADDRESSE_SKILL OR DeveloperName = :SKJERMEDE_PERSONER_SKILL
                ]) {
                    skillIdMap.put(skill.DeveloperName, skill.Id);
                }
            }
            return skillIdMap;
        }
        private set {
        }
    }

    private Set<Id> fortroligMembers = new Set<Id>();
    private Set<Id> skjermedeMembers = new Set<Id>();
    private Set<Id> fortroligSkillUsers = new Set<Id>();
    private Set<Id> skjermedeSkillUsers = new Set<Id>();

    public STO_GroupMemberSkillService() {
        getGroupMembers();
        initSkillUserSets();
    }

    /**
     * @description: Initalizes the set og userIds who are member of the fortrolig and skjermet
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    public void getGroupMembers() {
        for (GroupMember groupMember : [
            SELECT UserOrGroupId, Group.DeveloperName
            FROM GroupMember
            WHERE Group.DeveloperName IN :groupNamesToSync AND UserOrGroupId IN :nksUserMap.keySet()
        ]) {
            String userOrGroupId = String.valueOf(GroupMember.UserOrGroupId);
            if (groupMember.Group.DeveloperName == FORTROLIG_GROUP_NAME) {
                fortroligMembers.add(groupMember.UserOrGroupId);
            } else {
                skjermedeMembers.add(groupMember.UserOrGroupId);
            }
        }
    }

    /**
     * @description: Initializes the set og userIds having the fortrolig and skjermet skill
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    private void initSkillUserSets() {
        for (ServiceResourceSkill servSkill : [
            SELECT Id, ServiceResourceId, Skill.DeveloperName
            FROM ServiceResourceSkill
            WHERE Skill.DeveloperName = :FORTOLIG_ADDRESSE_SKILL OR Skill.DeveloperName = :SKJERMEDE_PERSONER_SKILL
        ]) {
            if (servSkill.Skill.DeveloperName == FORTOLIG_ADDRESSE_SKILL) {
                fortroligSkillUsers.add(servSkill.ServiceResourceId);
            } else {
                skjermedeSkillUsers.add(servSKill.ServiceResourceId);
            }
        }
    }

    public void handleGroupAndSkillSync() {
        //Ensures all NKS users have a related service resource created
        Map<Id, ServiceResource> userResourceMap = handleServiceResourceCreation(nksUserMap.keySet());
        handleSkillInsert(userResourceMap);
        handleSkillDeletion();
    }

    /**
     * @description: Inserts new skills for group members who have not yet been assigned the skill.
     * @author Stian Ruud Schikora | 12-16-2021
     * @param userResourceMap
     **/
    private void handleSkillInsert(Map<Id, ServiceResource> userResourceMap) {
        List<ServiceResourceSkill> skillsToCreate = new List<ServiceResourceSkill>();
        for (Id memberId : this.fortroligMembers) {
            //If a userId in the fortrolig group is not contained in the fortroligSkillUser set, we need to ass the skill for that user
            if (!fortroligSkillUsers.contains(memberId)) {
                skillsToCreate.add(createSkill(skillIdMap.get(FORTOLIG_ADDRESSE_SKILL), userResourceMap.get(memberId)));
            }
        }

        for (Id memberId : this.skjermedeMembers) {
            //If a userId in the fortrolig group is not contained in the skjermedeSkillUsers set, we need to ass the skill for that user
            if (!skjermedeSkillUsers.contains(memberId)) {
                skillsToCreate.add(
                    createSkill(skillIdMap.get(SKJERMEDE_PERSONER_SKILL), userResourceMap.get(memberId))
                );
            }
        }

        if (!skillsToCreate.isEmpty() && !Test.isRunningTest()) {
            List<Database.SaveResult> saveResList = Database.insert(skillsToCreate, false);
            verifySkillinsert(saveResList);
        }
    }

    /**
     * @description: Deletes the skill for all users who are no longer members og the synced groups
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    private void handleSkillDeletion() {
        //Get list of skills to be deleted for users who are not longer members of the synced AD groups
        List<ServiceResourceSkill> skillsToDelete = [
            SELECT Id, ServiceResourceId, Skill.DeveloperName
            FROM ServiceResourceSkill
            WHERE
                (Skill.DeveloperName = :FORTOLIG_ADDRESSE_SKILL
                AND ServiceResource.RelatedRecordId NOT IN :fortroligMembers)
                OR (Skill.DeveloperName = :SKJERMEDE_PERSONER_SKILL
                AND ServiceResource.RelatedRecordId NOT IN :skjermedeMembers)
        ];

        if (!skillsToDelete.isEmpty() && !Test.isRunningTest()) {
            List<Database.DeleteResult> deleteResList = Database.delete(skillsToDelete, false);
            verifySkillRemoval(deleteResList);
        }
    }

    /**
     * @description: Constructs a new ServiceResourceSkill record for the defined skill and service resource
     * @author Stian Ruud Schikora | 12-16-2021
     * @param skillId
     * @param servRes
     * @return ServiceResourceSkill
     **/
    private ServiceResourceSkill createSkill(Id skillId, ServiceResource servRes) {
        return new ServiceResourceSkill(
            ServiceResourceId = servRes.Id,
            SkillId = skillId,
            EffectiveStartDate = System.now()
        );
    }

    /**
     * @description: Asserts if there were any skill insert that failed and logs to application log
     * If the service resource is assigned the skill already the insert will fail with the DUPLICATE_VALUE status code and thus not treated as an error
     * @author Stian Ruud Schikora | 12-15-2021
     * @param saveResList
     **/
    @testVisible
    private void verifySkillinsert(List<Database.SaveResult> saveResList) {
        for (Database.SaveResult saveRes : saveResList) {
            if (saveRes.isSuccess()) {
                //Successfully inserted skill for the resource
            } else {
                for (Database.Error err : saveRes.getErrors()) {
                    if (err.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
                        //The resource is already assigned this skill
                    } else {
                        logger.error('Failed to create skill', null, CRM_ApplicationDomain.Domain.NKS);
                    }
                }
            }
        }
        logger.publish();
    }

    /**
     * @description: Asserts if there were any deletions that failed and logs to application log
     * @author Stian Ruud Schikora | 12-15-2021
     * @param deleteResList
     **/
    @testVisible
    private void verifySkillRemoval(List<Database.DeleteResult> deleteResList) {
        for (Database.DeleteResult delRes : deleteResList) {
            if (delRes.isSuccess()) {
                //Successfully inserted skill for the resource
            } else {
                for (Database.Error err : delRes.getErrors()) {
                    logger.error('Failed to create skill: ' + err.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
                }
            }
        }
        logger.publish();
    }

    /**
     * @description: Creates service resources for users who do not already have a resource connected to their user
     * Returns a map og userId -> ServiceResource
     * @author Stian Ruud Schikora | 12-15-2021
     * @param userIds
     * @return Map<Id, ServiceResource>
     **/
    private Map<Id, ServiceResource> handleServiceResourceCreation(Set<Id> userIds) {
        Map<Id, ServiceResource> userResourceMap = getServiceResources(userIds);
        //If the resource map contains less keys than input userIds, we need to create serviceresources
        if (userResourceMap.keySet().size() < userIds.size()) {
            List<ServiceResource> resourcesToCreate = new List<ServiceResource>();
            for (User usr : [SELECT Id, Name FROM User WHERE Id IN :userIds]) {
                if (!userResourceMap.containsKey(usr.Id)) {
                    resourcesToCreate.add(
                        new ServiceResource(
                            ResourceType = 'A',
                            RelatedRecordId = usr.Id,
                            Name = usr.Name,
                            IsActive = true
                        )
                    );
                }
            }

            insert resourcesToCreate;
            //Adding the newly created resources to the return map
            for (ServiceResource servRes : resourcesToCreate) {
                userResourceMap.put(servRes.RelatedRecordId, servRes);
            }
        }

        return userResourceMap;
    }

    /**
     * @description: Returns a map of userIds to a ServiceResource record
     * @author Stian Ruud Schikora | 12-14-2021
     * @return Map<Id, ServiceResource>
     **/
    private Map<Id, ServiceResource> getServiceResources(Set<Id> userIds) {
        Map<Id, ServiceResource> userResourceMap = new Map<Id, ServiceResource>();
        for (ServiceResource servRes : [
            SELECT Id, RelatedRecordId
            FROM ServiceResource
            WHERE RelatedRecordId IN :userIds AND ResourceType = 'A'
        ]) {
            userResourceMap.put(servRes.RelatedRecordId, servRes);
        }

        return userResourceMap;
    }
}

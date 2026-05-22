/**
 * @description This class is used to sync skills between groups and users
 * !IMPORTANT! This class can be called using the Callable interface
 * in other packaged wich are not dependent on crm-sto. (f.e. hot-servicetjenesten)
 * @updated : 2025-02-07
 */
public with sharing class STO_GroupMemberSkillService implements Callable {
    private LoggerUtility logger = new LoggerUtility('AD_SKILL_SYNC');
    public static final String FORTOLIG_ADDRESSE_SKILL = 'Fortrolig_addresse';
    public static final String SKJERMEDE_PERSONER_SKILL = 'Skjermede_personer';
    public static final String FORTROLIG_GROUP_NAME = 'group_AD_Fortrolig_Adresse';
    public static final String SKJERMEDE_GROUP_NAME = 'NKS_Skjermede_Personer_AD';
    public static final String PERMSET_GROUP_NAME = 'Kontaktsenter';
    public static final String SR_DOMAIN = 'NKS';
    public static final String RESOURCE_TYPE = 'A';
    private String fortroligGroupName = FORTROLIG_GROUP_NAME;
    private String skjermedeGroupName = SKJERMEDE_GROUP_NAME;
    private String permsetGroupName = PERMSET_GROUP_NAME;
    private String srDomain = SR_DOMAIN;
    private String srSubDomain;
    private String srType = RESOURCE_TYPE;
    private Set<Id> fortroligMembers = new Set<Id>();
    private Set<Id> skjermedeMembers = new Set<Id>();
    private Set<Id> fortroligSkillUsers = new Set<Id>();
    private Set<Id> skjermedeSkillUsers = new Set<Id>();
    @TestVisible
    private Map<Id, User> userMap;
    @TestVisible
    private Map<String, Id> skillIdMap;

    @TestVisible
    private Map<Id, User> initUserMap() {
        userMap = new Map<Id, User>(
            [
                SELECT Id, Name
                FROM User
                WHERE
                    Id IN (
                        SELECT AssigneeId
                        FROM PermissionSetAssignment
                        WHERE PermissionSetGroup.DeveloperName = :permsetGroupName
                    )
            ]
        );
        return userMap;
    }
    @TestVisible
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Map<String, Id> initSkillIdMap() {
        skillIdMap = new Map<String, Id>();
        for (Skill skill : [
            SELECT Id, DeveloperName
            FROM Skill
            WHERE DeveloperName = :FORTOLIG_ADDRESSE_SKILL OR DeveloperName = :SKJERMEDE_PERSONER_SKILL
        ]) {
            skillIdMap.put(skill.DeveloperName, skill.Id);
        }
        return skillIdMap;
    }

    /**
     * @description Initalizes the set og userIds who are member of the fortrolig and skjermet
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public void getGroupMembers() {
        for (GroupMember groupMember : [
            SELECT UserOrGroupId, Group.DeveloperName
            FROM GroupMember
            WHERE
                Group.DeveloperName IN (:fortroligGroupName, :skjermedeGroupName)
                AND UserOrGroupId IN :userMap.keySet()
        ]) {
            String userOrGroupId = String.valueOf(GroupMember.UserOrGroupId);
            if (groupMember.Group.DeveloperName == fortroligGroupName) {
                fortroligMembers.add(groupMember.UserOrGroupId);
            } else {
                skjermedeMembers.add(groupMember.UserOrGroupId);
            }
        }
    }

    /**
     * @description Initializes the set og userIds having the fortrolig and skjermet skill
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private void initSkillUserSets() {
        for (ServiceResourceSkill servSkill : [
            SELECT Id, ServiceResourceId, Skill.DeveloperName
            FROM ServiceResourceSkill
            WHERE
                (Skill.DeveloperName = :FORTOLIG_ADDRESSE_SKILL
                OR Skill.DeveloperName = :SKJERMEDE_PERSONER_SKILL)
                AND ServiceResource.CRM_Domain__c = :srDomain
        ]) {
            if (servSkill.Skill.DeveloperName == FORTOLIG_ADDRESSE_SKILL) {
                fortroligSkillUsers.add(servSkill.ServiceResourceId);
            } else {
                skjermedeSkillUsers.add(servSKill.ServiceResourceId);
            }
        }
    }
    /**
     * @description Handles syncronization of users having a groupmember to the skills they have
     */
    public void handleGroupAndSkillSync() {
        initUserMap();
        initSkillIdMap();
        getGroupMembers();
        initSkillUserSets();
        //Ensures all NKS users have a related service resource created
        handleSkillInsert();
        handleSkillDeletion();
    }

    /**
     * @description Inserts new skills for group members who have not yet been assigned the skill.
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    private void handleSkillInsert() {
        Map<Id, ServiceResource> userResourceMap = handleServiceResourceCreation();
        List<ServiceResourceSkill> skillsToCreate = new List<ServiceResourceSkill>();
        for (Id memberId : fortroligMembers) {
            //If a userId in the fortrolig group is not contained in the fortroligSkillUser set, we need to ass the skill for that user
            if (!fortroligSkillUsers.contains(memberId)) {
                skillsToCreate.add(createSkill(skillIdMap.get(FORTOLIG_ADDRESSE_SKILL), userResourceMap.get(memberId)));
            }
        }

        for (Id memberId : skjermedeMembers) {
            //If a userId in the fortrolig group is not contained in the skjermedeSkillUsers set, we need to ass the skill for that user
            if (!skjermedeSkillUsers.contains(memberId)) {
                skillsToCreate.add(
                    createSkill(skillIdMap.get(SKJERMEDE_PERSONER_SKILL), userResourceMap.get(memberId))
                );
            }
        }

        if (!skillsToCreate.isEmpty()) {
            List<Database.SaveResult> saveResList = Database.insert(skillsToCreate, false);
            verifySkillinsert(saveResList);
        }
    }

    /**
     * @description Deletes the skill for all users who are no longer members og the synced groups
     * @author Stian Ruud Schikora | 12-16-2021
     **/
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private void handleSkillDeletion() {
        //Get list of skills to be deleted for users who are not longer members of the synced AD groups
        List<ServiceResourceSkill> skillsToDelete = new List<ServiceResourceSkill>();
        for (ServiceResourceSkill servSkill : [
            SELECT Id, ServiceResourceId, ServiceResource.RelatedRecordId, Skill.DeveloperName
            FROM ServiceResourceSkill
            WHERE
                ServiceResource.CRM_Domain__c = :srDomain
                AND (Skill.DeveloperName = :FORTOLIG_ADDRESSE_SKILL
                OR Skill.DeveloperName = :SKJERMEDE_PERSONER_SKILL)
        ]) {
            if (servSkill.Skill.DeveloperName == FORTOLIG_ADDRESSE_SKILL 
                && !fortroligMembers.contains(servSkill.ServiceResource.RelatedRecordId)) {
                skillsToDelete.add(servSkill);
            } else if (servSkill.Skill.DeveloperName == SKJERMEDE_PERSONER_SKILL 
                && !skjermedeMembers.contains(servSkill.ServiceResource.RelatedRecordId)) {
                skillsToDelete.add(servSkill);
            }
        }

        if (!skillsToDelete.isEmpty()) {
            List<Database.DeleteResult> deleteResList = Database.delete(skillsToDelete, false);
            verifySkillRemoval(deleteResList);
        }
    }

    /**
     * @description Constructs a new ServiceResourceSkill record for the defined skill and service resource
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
     * @description Asserts if there were any skill insert that failed and logs to application log
     * If the service resource is assigned the skill already the insert will fail with the DUPLICATE_VALUE status code and thus not treated as an error
     * @author Stian Ruud Schikora | 12-15-2021
     * @param saveResList
     **/
    @TestVisible
    private void verifySkillinsert(List<Database.SaveResult> saveResList) {
        for (Database.SaveResult saveRes : saveResList) {
            if (!saveRes.isSuccess()) {
                for (Database.Error err : saveRes.getErrors()) {
                    //Skip already assigned skill
                    if (!(err.getStatusCode() == StatusCode.DUPLICATE_VALUE)) {
                        logger.error('Failed to create skill', null, CRM_ApplicationDomain.Domain.valueOf(srDomain));
                    }
                }
            }
        }
        logger.publish();
    }

    /**
     * @description Asserts if there were any deletions that failed and logs to application log
     * @author Stian Ruud Schikora | 12-15-2021
     * @param deleteResList
     **/
    @TestVisible
    private void verifySkillRemoval(List<Database.DeleteResult> deleteResList) {
        for (Database.DeleteResult delRes : deleteResList) {
            if (!delRes.isSuccess()) {
                for (Database.Error err : delRes.getErrors()) {
                    logger.error(
                        'Failed to create skill: ' + err.getMessage(),
                        null,
                        CRM_ApplicationDomain.Domain.valueOf(srDomain)
                    );
                }
            }
        }
        logger.publish();
    }

    /**
     * @description Creates service resources for users who do not already have a resource connected to their user
     * Returns a map og userId -> ServiceResource
     * @author Stian Ruud Schikora | 12-15-2021
     * @return Map<Id, ServiceResource>
     **/
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Map<Id, ServiceResource> handleServiceResourceCreation() {
        Map<Id, ServiceResource> userResourceMap = getServiceResources();
        //If the resource map contains less keys than input userIds, we need to create serviceresources
        Set<Id> usersWithoutSR = new Set<Id>(userMap.keySet());
        usersWithoutSR.removeAll(userResourceMap.keySet());
        List<ServiceResource> resourcesToCreate = new List<ServiceResource>();
        for (Id userId : usersWithoutSR) {
            User usr = userMap.get(userId);
            resourcesToCreate.add(
                new ServiceResource(
                    ResourceType = srType,
                    RelatedRecordId = usr.Id,
                    Name = usr.Name,
                    IsActive = true,
                    CRM_Domain__c = srDomain,
                    CRM_Subdomain__c = srSubDomain
                )
            );
        }
        if (resourcesToCreate.size() > 0) {
            insert resourcesToCreate;
        }
        for (ServiceResource servRes : resourcesToCreate) {
            userResourceMap.put(servRes.RelatedRecordId, servRes);
        }

        return userResourceMap;
    }

    /**
     * @description Returns a map of userIds to a ServiceResource record of same type
     * @author Stian Ruud Schikora | 12-14-2021
     * @return Map<Id, ServiceResource>
     **/
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private Map<Id, ServiceResource> getServiceResources() {
        Map<Id, ServiceResource> userResourceMap = new Map<Id, ServiceResource>();
        List<ServiceResource> serviceResuorcesOtherDomain = new List<ServiceResource>();
        for (ServiceResource servRes : [
            SELECT Id, RelatedRecordId, CRM_Domain__c, CRM_SubDomain__c
            FROM ServiceResource
            WHERE RelatedRecordId IN :userMap.keySet() AND ResourceType = :srType
        ]) {
            userResourceMap.put(servRes.RelatedRecordId, servRes);
            if (servRes.CRM_Domain__c != srDomain || servRes.CRM_SubDomain__c != srSubDomain) {
                serviceResuorcesOtherDomain.add(servRes);
            }
        }
        if (serviceResuorcesOtherDomain.size() > 0) {
            // it is not allouwed to have several ServiceResource of same Type for one User
            // logging if users have related ServiceResources but in Other Domain
            logger.info(
                'Already existing ServiceResources of same Type in other (Sub)Domain: ' +
                JSON.serializePretty(serviceResuorcesOtherDomain),
                null,
                CRM_ApplicationDomain.Domain.valueOf(srDomain)
            );
            logger.publish();
        }

        return userResourceMap;
    }
    /**
     * @description Executes handleGroupAndSkillSync from an external package(hot-servicetjenesten)
     * @author Eugenijus Margalikas | 07.02.2025
     * @param action - `String` - Action to execute for now only `handleGroupAndSkillSync`
     * @param args -  `Map<String,String>` where
     * keys are domain,subdomain,permsetgroup,fortroliggroup,skjermedegroup
     * @return Object
     */
    public Object call(String action, Map<String, Object> args) {
        switch on action.toLowerCase() {
            when 'handlegroupandskillsync' {
                setParams(args).handleGroupAndSkillSync();
                return 0;
            }
            when else {
                throw new STO_SkillServiceMalformedCallException('Action: ' + action + ' is not implemented');
            }
        }
    }
    @TestVisible
    private STO_GroupMemberSkillService setParams(Map<String, Object> params) {
        for (String key : params.keySet()) {
            if (params.get(key) == null || !(params.get(key) instanceof String)) {
                continue;
            }
            switch on key.toLowerCase() {
                when 'domain' {
                    srDomain = (String) params.get(key);
                }
                when 'subdomain' {
                    srSubDomain = (String) params.get(key);
                }
                when 'permsetgroup' {
                    permsetGroupName = (String) params.get(key);
                }
                when 'fortroliggroup' {
                    fortroligGroupName = (String) params.get(key);
                }
                when 'skjermedegroup' {
                    skjermedeGroupName = (String) params.get(key);
                }
                when 'resourcetype' {
                    srType = (String) params.get(key);
                }
            }
        }
        return this;
    }
    /**
     * @description Custom exception type for handling malformed calls.
     */
    public class STO_SkillServiceMalformedCallException extends Exception {
    }
}

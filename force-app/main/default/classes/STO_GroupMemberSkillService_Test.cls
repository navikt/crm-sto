@isTest
public class STO_GroupMemberSkillService_Test {
    @TestSetup
    static void makeData() {
        Group fortroligGroup = TestDataFactory.getPublicGroup('Fortrolig_Adresse_AD', 'Fortrolig_Adresse_AD');
        Group skjermedeGroup = TestDataFactory.getPublicGroup('NKS_Skjermede_Personer_AD', 'NKS_Skjermede_Personer_AD');

        //Adds the testuser as a member in both groups
        User usr = (User) STO_TestDataFactory.createRecord(new User(FirstName = 'SUPER', LastName = 'SKILLED'));
        List<GroupMember> memberList = new List<GroupMember>();
        memberList.add(new GroupMember(GroupId = fortroligGroup.Id, UserOrGroupId = usr.Id));
        memberList.add(new GroupMember(GroupId = skjermedeGroup.Id, UserOrGroupId = usr.Id));
        STO_TestDataFactory.createRecordList(memberList);
    }

    @isTest
    static void testSkillCreate() {
        User testUser = [SELECT Id, Name FROM User WHERE LastName = 'SKILLED'];
        STO_GroupMemberSkillService.nksUserMap.clear();
        STO_GroupMemberSkillService.nksUserMap.put(testUser.Id, testUser); //Override the return of the map since the permission set group does not exist in this package
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();

        Test.startTest();
        service.handleGroupAndSkillSync();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ServiceResource]);
        System.assertEquals(2, [SELECT COUNT() FROM ServiceResourceSkill]);
    }

    @isTest
    static void testSkillRemove() {
        User testUser = [SELECT Id, Name FROM User WHERE LastName = 'SKILLED'];
        STO_GroupMemberSkillService.nksUserMap.clear();
        STO_GroupMemberSkillService.nksUserMap.put(testUser.Id, testUser); //Override the return of the map since the permission set group does not exist in this package
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        service.handleGroupAndSkillSync();

        //Verify that the skill was assigned
        System.assertNotEquals(
            0,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE
                    ServiceResource.RelatedRecordId = :testUser.Id
                    AND Skill.DeveloperName = :STO_GroupMemberSkillService.SKJERMEDE_PERSONER_SKILL
            ]
        );
        Test.startTest();
        //Removing from the skjermede group
        removeFromGroup(testUser.Id, 'NKS_Skjermede_Personer_AD');
        Test.stopTest();
        //Create new service as the memberlist have changed
        STO_GroupMemberSkillService service2 = new STO_GroupMemberSkillService();
        service2.handleGroupAndSkillSync();

        //Verify that the skill was removed
        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE
                    ServiceResource.RelatedRecordId = :testUser.Id
                    AND Skill.DeveloperName = :STO_GroupMemberSkillService.SKJERMEDE_PERSONER_SKILL
            ]
        );
        //Verify that the fortrolig skill is still present
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE
                    ServiceResource.RelatedRecordId = :testUser.Id
                    AND Skill.DeveloperName = :STO_GroupMemberSkillService.FORTOLIG_ADDRESSE_SKILL
            ]
        );
    }

    @future
    private static void removeFromGroup(Id userId, String groupDevName) {
        delete [SELECT Id FROM GroupMember WHERE UserOrGroupId = :userId AND Group.DeveloperName = :groupDevName];
    }
}

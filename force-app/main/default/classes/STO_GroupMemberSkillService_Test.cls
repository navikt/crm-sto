@IsTest
public class STO_GroupMemberSkillService_Test {
    @TestSetup
    private static void makeData() {
        myTriggers.disable(PersonAccessHandler.class);
        myTriggers.disable(UserPermissionSetAssignmentHandler.class);
        myTriggers.disable(UserDefaultValuesHandler.class);
        myTriggers.disable(UserProfileHandler.class);
        myTriggers.disable(UserGroupMemberHandler.class);
        myTriggers.disable(UserRegionHandler.class);
        myTriggers.disable(UserRoleAssignmentHandler.class);
        Group fortroligGroup = TestDataFactory.getPublicGroup(
            'group_AD_Fortrolig_Adresse',
            'group_AD_Fortrolig_Adresse'
        );
        Group nksSkjermedeGroup = TestDataFactory.getPublicGroup(
            'NKS_Skjermede_Personer_AD',
            'NKS_Skjermede_Personer_AD'
        );
        Group skjermedeGroup = TestDataFactory.getPublicGroup('Skjermede_Personer_AD', 'Skjermede_Personer_AD');

        //Adds the testuser as a member in both groups
        User usr1 = (User) STO_TestDataFactory.createRecord(new User(FirstName = 'SUPER', LastName = 'SKILLED'));
        User usr2 = (User) STO_TestDataFactory.createRecord(new User(FirstName = 'HOTST', LastName = 'HOTST'));
        List<GroupMember> memberList = new List<GroupMember>();
        memberList.add(new GroupMember(GroupId = fortroligGroup.Id, UserOrGroupId = usr1.Id));
        memberList.add(new GroupMember(GroupId = nksSkjermedeGroup.Id, UserOrGroupId = usr1.Id));
        memberList.add(new GroupMember(GroupId = fortroligGroup.Id, UserOrGroupId = usr2.Id));
        memberList.add(new GroupMember(GroupId = skjermedeGroup.Id, UserOrGroupId = usr2.Id));
        STO_TestDataFactory.createRecordList(memberList);
        PermissionSetGroup kontaktsenterPSG;
        PermissionSetGroup servicetjenestenPSG;
        List<PermissionSetGroup> psgs = [
            SELECT Id, DeveloperName
            FROM PermissionSetGroup
            WHERE DeveloperName IN ('Kontaktsenter', 'HOT_Servicetjenesten_Group')
        ];
        for (PermissionSetGroup psg : psgs) {
            if (psg.DeveloperName == 'Kontaktsenter') {
                kontaktsenterPSG = psg;
            } else if (psg.DeveloperName == 'HOT_Servicetjenesten_Group') {
                servicetjenestenPSG = psg;
            }
        }
        if (kontaktsenterPSG == null) {
            kontaktsenterPSG = new PermissionSetGroup(MasterLabel = 'Kontaktsenter', DeveloperName = 'Kontaktsenter');
            insert kontaktsenterPSG;
        }
        if (servicetjenestenPSG == null) {
            servicetjenestenPSG = new PermissionSetGroup(
                MasterLabel = 'Servicetjenesten',
                DeveloperName = 'HOT_Servicetjenesten_Group'
            );
            insert servicetjenestenPSG;
        }
        PermissionSetAssignment psa1 = new PermissionSetAssignment(
            AssigneeId = usr1.ID,
            PermissionSetGroupId = kontaktsenterPSG.Id
        );
        PermissionSetAssignment psa2 = new PermissionSetAssignment(
            AssigneeId = usr2.ID,
            PermissionSetGroupId = servicetjenestenPSG.Id
        );
        insert new List<PermissionSetAssignment>{ psa1, psa2 };

        if (
            [
                    SELECT Id, DeveloperName
                    FROM Skill
                    WHERE DeveloperName = 'Fortrolig_addresse'
                ]
                .isEmpty()
        ) {
            Test.loadData(Skill.sObjectType, 'testFortroligSkill');
        }
        if (
            [
                    SELECT Id, DeveloperName
                    FROM Skill
                    WHERE DeveloperName = 'Skjermede_Personer'
                ]
                .isEmpty()
        ) {
            Test.loadData(Skill.sObjectType, 'testSkjermetSkill');
        }
    }

    @IsTest
    private static void nksServiceResourceWithSkillCreate() {
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    UserOrGroupId IN (SELECT Id FROM User WHERE LastName = 'SKILLED')
                    AND Group.DeveloperName IN (
                        'group_AD_Fortrolig_Adresse',
                        'NKS_Skjermede_Personer_AD',
                        'Skjermede_Personer_AD'
                    )
            ]
        );
        Test.startTest();
        service.handleGroupAndSkillSync();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'SKILLED'],
            'Expected serviceresource for NKS user'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'HOTST'],
            'Expected no serviceresource for HOT user'
        );

        ServiceResource nksSR = [
            SELECT Id, RelatedRecordId, CRM_Domain__c
            FROM ServiceResource
            WHERE RelatedRecord.LastName = 'SKILLED'
            LIMIT 1
        ];
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE ServiceResourceId = :nksSR.Id
            ],
            'Expected 2 skills for NKS user'
        );
    }
    @IsTest
    private static void hotServiceResourceWithSkillCreate() {
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        service.setParams(
            new Map<String, String>{
                'domain' => 'HOT',
                'subdomain' => 'Servicetjenesten',
                'permsetgroup' => 'HOT_Servicetjenesten_Group',
                'fortroliggroup' => 'group_AD_Fortrolig_Adresse',
                'skjermedegroup' => 'Skjermede_Personer_AD'
            }
        );
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    UserOrGroupId IN (SELECT Id FROM User WHERE LastName = 'HOTST')
                    AND Group.DeveloperName IN (
                        'group_AD_Fortrolig_Adresse',
                        'NKS_Skjermede_Personer_AD',
                        'Skjermede_Personer_AD'
                    )
            ]
        );
        Test.startTest();
        service.handleGroupAndSkillSync();
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'HOTST'],
            'Expected serviceresource for HOT user'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'SKILLED'],
            'Expected no serviceresource for NKS user'
        );

        ServiceResource hotSR = [
            SELECT Id, RelatedRecordId, RelatedRecord.LastName, CRM_Domain__c
            FROM ServiceResource
            WHERE RelatedRecord.LastName = 'HOTST'
            LIMIT 1
        ];
        System.assertEquals('HOT', hotSR.CRM_Domain__c, 'Expected HOT domain');
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE ServiceResourceId = :hotSR.Id
            ],
            'Expected 2 skills for HOT user'
        );
    }

    @IsTest
    private static void callableSync() {
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM GroupMember
                WHERE
                    UserOrGroupId IN (SELECT Id FROM User WHERE LastName = 'HOTST')
                    AND Group.DeveloperName IN (
                        'group_AD_Fortrolig_Adresse',
                        'NKS_Skjermede_Personer_AD',
                        'Skjermede_Personer_AD'
                    )
            ]
        );
        Test.startTest();
        try {
            Callable syncService = (Callable) Type.forName('STO_GroupMemberSkillService').newInstance();
            syncService.call(
                'handleGroupAndSkillSync',
                new Map<String, Object>{
                    'domain' => 'HOT',
                    'subdomain' => 'Servicetjenesten',
                    'permsetgroup' => 'HOT_Servicetjenesten_Group',
                    'fortroliggroup' => 'group_AD_Fortrolig_Adresse',
                    'skjermedegroup' => 'Skjermede_Personer_AD'
                }
            );
        } catch (Exception e) {
            System.Assert.isTrue(false, 'Could not call callable class' + e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'HOTST'],
            'Expected serviceresource for HOT user'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM ServiceResource WHERE RelatedRecord.LastName = 'SKILLED'],
            'Expected no serviceresource for NKS user'
        );

        ServiceResource hotSR = [
            SELECT Id, RelatedRecordId, RelatedRecord.LastName, CRM_Domain__c
            FROM ServiceResource
            WHERE RelatedRecord.LastName = 'HOTST'
            LIMIT 1
        ];
        System.assertEquals('HOT', hotSR.CRM_Domain__c, 'Expected HOT domain');
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE ServiceResourceId = :hotSR.Id
            ],
            'Expected 2 skills for HOT user'
        );
    }

    @IsTest
    private static void testSkillRemove() {
        User testUser = [SELECT Id, Name FROM User WHERE LastName = 'SKILLED'];
        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        service.handleGroupAndSkillSync();
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE ServiceResource.RelatedRecordId = :testUser.Id
            ],
            'Expected 2 skills for NKS user'
        );
        Test.startTest();
        //Removing from the skjermede group
        removeFromGroup(testUser.Id, 'NKS_Skjermede_Personer_AD');
        Test.stopTest();
        //Create new service as the memberlist have changed
        STO_GroupMemberSkillService service2 = new STO_GroupMemberSkillService();
        service2.handleGroupAndSkillSync();
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM ServiceResourceSkill
                WHERE ServiceResource.RelatedRecordId = :testUser.Id
            ],
            'Expected 1 skills for NKS user'
        );
    }

    @IsTest
    private static void testDmlVerification() {
        Account testAcc = new Account(Name = 'Test Account');
        User testUser = [SELECT Id, Name FROM User WHERE LastName = 'SKILLED'];
        List<Database.SaveResult> saveResList = Database.insert(new List<SObject>{ testAcc, testUser }, false);

        List<Database.DeleteResult> deleteResList = Database.delete(new List<SObject>{ testAcc, testUser }, false);

        STO_GroupMemberSkillService service = new STO_GroupMemberSkillService();
        service.handleGroupAndSkillSync();

        Test.startTest();
        service.verifySkillinsert(saveResList);
        service.verifySkillRemoval(deleteResList);
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Application_Log__c]); //Two errors should be logged
    }
    @future
    private static void removeFromGroup(Id userId, String groupDevName) {
        delete [SELECT Id FROM GroupMember WHERE UserOrGroupId = :userId AND Group.DeveloperName = :groupDevName];
    }
}

@IsTest
public with sharing class BTO_AssignBatchTest {
    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        User u = new User(
            ProfileId = p.Id,
            lastName = 'Testy',
            Username = 'marihone@testy.com',
            email = 'marihone@testy.com',
            alias = 'marih',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        ServiceResource s = new ServiceResource(RelatedRecordId = u.Id, IsActive = true, name = 'testy');
        insert s;
    }

    @IsTest
    static void testNotAssignEmptySR() {
        Test.startTest();
        Database.executeBatch(new BTO_AssignBatch('Standard User'));
        Test.stopTest();
        List<ServiceResourceSkill> skills = [
            SELECT Id
            FROM ServiceResourceSkill
            WHERE
                ServiceResource.RelatedRecord.Profile.Name LIKE 'Standard User'
                AND Skill.DeveloperName IN ('STO', 'BTO')
        ];
        System.assertEquals(0, skills.size(), 'A user without any STO skills was assigned new skills.');
    }

    @IsTest
    static void testBTOAssign() {
        List<sObject> testSR = [
            SELECT Id
            FROM ServiceResource
            WHERE RelatedRecord.Profile.Name LIKE 'Standard User'
            LIMIT 1
        ];
        Test.startTest();
        new BTO_AssignBatch('Standard User').execute(null, testSR);
        Test.stopTest();
        List<ServiceResourceSkill> skills = [
            SELECT Id
            FROM ServiceResourceSkill
            WHERE
                ServiceResource.RelatedRecord.Profile.Name LIKE 'Standard User'
                AND Skill.DeveloperName IN ('STO', 'BTO')
        ];
        System.assertEquals(2, skills.size(), 'User was not assigned new STO/BTO skills');
    }
}

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
        Skill arbeidSkill = [SELECT Id FROM Skill WHERE DeveloperName = 'Arbeid' LIMIT 1];
        ServiceResourceSkill sk = new ServiceREsourceSkill(
            ServiceResourceId = s.Id,
            SkillId = arbeidSkill.Id,
            SkillLevel = 1,
            EffectiveStartDate = Date.today().addDays(-1)
        );
        insert sk;
    }

    @IsTest
    static void testBTOAssign() {
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
        System.assertEquals(2, skills.size(), 'User did not get assigned both STO and BTO skills');
    }
}

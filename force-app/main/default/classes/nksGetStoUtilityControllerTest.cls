@isTest
public with sharing class nksGetStoUtilityControllerTest {
    @TestSetup
    static void makeData(){
        /*
        List<Person__c> persons = STO_TestDataFactory.createPersons(2);
        List<Id> personIds = new List<Id>();
        for(Person__c p : persons){
            personIds.add(p.Id);
        }
        List<Account> accs = [SELECT Id FROM Account WHERE CRM_Person__c IN :personIds];

        Case c = new Case();
        c.AccountId = accs[0].Id;
        c.Status = 'New';
        c.Origin = 'STO';
        c.STO_Category__c = 'Familie';
        c.CRM_Run_Case_Assignment__c = true;

        insert c;

        User usr = (User) STO_TestDataFactory.createRecord(new User(FirstName = 'SUPER', LastName = 'SKILLED'));
        
        ServiceResource sr = new ServiceResource();
        sr.Name = 'TestResource';
        sr.ResourceType = 'A';
        sr.RelatedRecordId = usr.Id;
        sr.IsActive = true;
        insert sr;


        Skill s = [SELECT Id FROM Skill WHERE DeveloperName = 'Familie' LIMIT 1];

        ServiceResourceSkill srs = new ServiceResourceSkill();
        srs.ServiceResourceId = sr.Id;
        srs.SkillId = s.Id;
        srs.EffectiveStartDate = Date.today();

        insert srs;
        */

    }

    @isTest
    static void testTest(){
        /*
        List<Case> c = [SELECT Id, CaseNumber, Status, OwnerId, STO_Category__c, AccountId, Origin, CRM_Run_Case_Assignment__c FROM Case];
        System.debug(c);
        List<SkillRequirement> skillr = [SELECT RelatedRecordId, SkillId, Skill.DeveloperName FROM SkillRequirement];
        System.debug(skillr);
        List<ServiceResourceSkill> srs = [SELECT Id, SkillId, ServiceResource.RelatedRecordId FROM ServiceResourceSkill];
        System.debug(srs);
        List<ServiceResource> sr = [SELECT Id, Name, ResourceType, RelatedRecord.FirstName FROM ServiceResource];
        System.debug(sr);
        */
    }
    @isTest
    static void getServiceResourceSkillIdsTest(){
        /*
        User u = [SELECT Id FROM User WHERE FirstName = 'SUPER'];
        List<Id> skillIdList = nksGetStoUtilityController.getServiceResourceSkillIds(u.Id);
        System.assertEquals(1, skillIdList.size(), 'Service resource has one skill.');
        */
    }
}

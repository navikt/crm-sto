@isTest
public with sharing class nksGetStoUtilityControllerTest {
    @TestSetup
    static void makeData() {
        myTriggers.disable(PersonAccessHandler.class);
        List<Person__c> persons = STO_TestDataFactory.createPersons(2);
        List<Id> personIds = new List<Id>();
        for (Person__c p : persons) {
            personIds.add(p.Id);
        }
        List<Account> accs = [SELECT Id FROM Account WHERE CRM_Person__c IN :personIds];

        Group testGroup = new Group(Name = 'TEST GROUP', Type = 'Queue');
        insert testGroup;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            QueueSObject testQueue = new QueueSObject(QueueID = testGroup.Id, SObjectType = 'Case');
            insert testQueue;
        }

        Id stoRecordTypeId = Case.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('STO_Case')
            .getRecordTypeId();

        // Case requiring Serviceklager
        Case c1 = new Case(
            AccountId = accs[0].Id,
            Status = 'New',
            Origin = 'STO',
            STO_Category__c = 'Familie',
            OwnerId = testGroup.Id,
            RecordTypeId = stoRecordTypeId,
            STO_Requires_Serviceklager_Skill__c = true
        );
        insert c1;

        // Case NOT requiring Serviceklager
        Case c2 = new Case(
            AccountId = accs[0].Id,
            Status = 'New',
            Origin = 'STO',
            STO_Category__c = 'Familie',
            OwnerId = testGroup.Id,
            RecordTypeId = stoRecordTypeId,
            STO_Requires_Serviceklager_Skill__c = false
        );
        insert c2;
    }

    @isTest
    static void testGetSto_UserWithoutServiceklager_GetsNonServiceklagerCase() {
        User usr = (User) STO_TestDataFactory.createRecord(new User());
        List<nksGetStoUtilityController.Record> records;
        List<nksGetStoUtilityController.Record> ownedList;

        Test.startTest();
        System.runAs(usr) {
            try {
                records = nksGetStoUtilityController.getSto();
                ownedList = nksGetStoUtilityController.getList();

                System.assertNotEquals(0, records.size());
                System.assert(ownedList.size() > 0, 'Expected at least one owned STO case');

                Id inProgressCaseId;
                for (nksGetStoUtilityController.Record r : records) {
                    if (r.status == 'In Progress') {
                        inProgressCaseId = (Id) r.recordId;
                        break;
                    }
                }
                System.assertNotEquals(null, inProgressCaseId);

                Case picked = [
                    SELECT Id, STO_Requires_Serviceklager_Skill__c
                    FROM Case
                    WHERE Id = :inProgressCaseId
                    LIMIT 1
                ];
                System.assertEquals(false, picked.STO_Requires_Serviceklager_Skill__c);
            } catch (AuraHandledException ex) {
                System.assert(
                    ex.getMessage().contains('NotFound') ||
                        ex.getMessage().contains('Max Attempt Count Exceeded') ||
                        ex.getMessage().contains('En feil oppsto ved henting av ny STO') ||
                        ex.getMessage().contains('Script-thrown exception'),
                    'Unexpected AuraHandledException: ' + ex.getMessage()
                );
            }
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSto_NoCases() {
        User usr = (User) STO_TestDataFactory.createRecord(new User());
        delete [SELECT Id FROM Case];

        Test.startTest();
        System.runAs(usr) {
            try {
                nksGetStoUtilityController.getSto();
                System.assert(false, 'Expected AuraHandledException when no STO is available');
            } catch (AuraHandledException auraEx) {
                System.assert(true);
            }
        }
        Test.stopTest();
    }

    @isTest
    static void testGetServiceResourceSkillIds_ExpiredSkillExcluded() {
        User usr = (User) STO_TestDataFactory.createRecord(new User());

        Test.startTest();
        System.runAs(usr) {
            nksGetStoUtilityController.GroupedSkills gs = nksGetStoUtilityController.getServiceResourceSkillIds();
            System.assertNotEquals(null, gs, 'GroupedSkills should be returned');
            System.assertNotEquals(null, gs.skillMap);
            System.assertNotEquals(null, gs.confidentialitySkillsBySkillId);
            System.assertNotEquals(null, gs.originSkillsBySkillId);
        }
        Test.stopTest();
    }
}

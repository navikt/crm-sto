@isTest
public with sharing class nksGetStoUtilityControllerTest {
    @TestSetup
    static void makeData() {
        List<Person__c> persons = STO_TestDataFactory.createPersons(2);
        List<Id> personIds = new List<Id>();
        for (Person__c p : persons) {
            personIds.add(p.Id);
        }
        List<Account> accs = [SELECT Id FROM Account WHERE CRM_Person__c IN :personIds];

        Group testGroup = new Group(Name = 'TEST GROUP', Type = 'Queue');
        insert testGroup;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            QueuesObject testQueue = new QueueSObject(QueueID = testGroup.id, SObjectType = 'Case');
            insert testQueue;
        }

        String STO_RECORD_TYPE = Case.getSObjectType()
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('STO_Case')
            .getRecordTypeId();

        Case c = new Case();
        c.AccountId = accs[0].Id;
        c.Status = 'New';
        c.Origin = 'STO';
        c.STO_Category__c = 'Familie';
        c.OwnerId = testGroup.Id;
        c.RecordTypeId = STO_RECORD_TYPE;

        insert c;

        Case c2 = new Case();
        c2.AccountId = accs[0].Id;
        c2.Status = 'New';
        c2.Origin = 'STO';
        c2.STO_Category__c = 'Familie';
        c2.OwnerId = testGroup.Id;
        c2.RecordTypeId = STO_RECORD_TYPE;

        insert c2;
    }

    @isTest
    static void testGetSto() {
        User usr = (User) STO_TestDataFactory.createRecord(new User());
        List<nksGetStoUtilityController.Record> records;
        List<nksGetStoUtilityController.Record> noRecord;
        List<nksGetStoUtilityController.Record> ownedList;

        Test.startTest();
        System.runAs(usr) {
            records = nksGetStoUtilityController.getSto();
            ownedList = nksGetStoUtilityController.getList('10');
        }
        delete [SELECT Id FROM Case];
        System.runAs(usr) {
            try {
                noRecord = nksGetStoUtilityController.getSto();
                System.assert(false);
            } catch (AuraHandledException auraEx) {
                System.assert(true);
            }
        }
        Test.stopTest();

        System.assertNotEquals(0, records.size());
        System.assertEquals(2, ownedList.size());
    }
}

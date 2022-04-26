@isTest
public with sharing class STO_RecordInfoControllerTest {
    @TestSetup
    static void makeData() {
        Person__c person = new Person__c(
            Name = '1234567890',
            INT_MunicipalityNumber__c = '0301',
            INT_FirstName__c = 'Navn',
            INT_LastName__c = 'Navnesen',
            INT_Confidential__c = 'UGRADERT',
            INT_MaritalStatus__c = 'UOPPGITT'
        );
        insert person;

        String personAccountRecordType = Schema.getGlobalDescribe()
            .get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        Account account = new Account(
            FirstName = 'Navn',
            LastName = 'Navnesen',
            INT_PersonIdent__c = '1234567890',
            RecordTypeId = personAccountRecordType,
            CRM_Person__c = person.Id
        );
        insert account;

        insert new NavUnit__c(Name = 'Test Unit', INT_UnitNumber__c = '1234');

        STO_TestDataFactory.createRecord(new Thread__c());
    }

    @isTest
    static void getRelatedRecordTest() {
        Account testAccount = [SELECT Id FROM Account WHERE LastName = 'Navnesen' LIMIT 1];
        Test.startTest();
        testAccount = (Account) STO_RecordInfoController.getRelatedRecord(
            String.valueOf(testAccount.Id),
            'CRM_Person__c',
            'Account'
        );
        Test.stopTest();
        System.assertNotEquals(null, testAccount.CRM_Person__c);
    }

    @isTest
    static void testGetByApiReference() {
        String apiRef = [SELECT CRM_API_Reference__c FROM Thread__c LIMIT 1]?.CRM_API_Reference__c;

        System.assertNotEquals(null, STO_RecordInfoController.getThreadIdByApiReference(apiRef));
    }

    @isTest
    static void testGetUnitName() {
        Test.startTest();
        System.assertEquals(
            'Test Unit',
            STO_RecordInfoController.getUnitNameFromUnitNumber('1234'),
            'Expected to get the correct unit number'
        );
        System.assertEquals(
            '',
            STO_RecordInfoController.getUnitNameFromUnitNumber('12345'),
            'Expected to get an empty string when there is no matching units'
        );
        System.assertEquals(
            '',
            STO_RecordInfoController.getUnitNameFromUnitNumber(''),
            'Expected to get blank string when unit number is empty string'
        );
        System.assertEquals(
            '',
            STO_RecordInfoController.getUnitNameFromUnitNumber(null),
            'Expected to get blank string when unit number is null'
        );
        Test.stopTest();
    }
}

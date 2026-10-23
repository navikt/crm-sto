@isTest
public with sharing class STO_RecordInfoControllerTest {
    @TestSetup
    static void makeData() {
        myTriggers.disable(PersonAccessHandler.class);
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

    @IsTest
    static void replyGreetingUsesOriginalSenderNotRepresentedChildOrLatestSender() {
        Contact child = [SELECT Id FROM Contact WHERE Account.LastName = 'Navnesen' LIMIT 1];
        Contact parent = new Contact(FirstName = 'Anne', LastName = 'Normann');
        insert parent;
        Thread__c thread = new Thread__c(CRM_Thread_Type__c = 'STO', CRM_Contact__c = child.Id);
        insert thread;
        Message__c initial = new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Parent starts on behalf of child',
            CRM_From_Contact__c = parent.Id,
            CRM_External_Message__c = true,
            CRM_Sent_date__c = Datetime.now().addDays(-1)
        );
        insert initial;
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Later sender must not replace the starter',
            CRM_From_Contact__c = child.Id,
            CRM_External_Message__c = true,
            CRM_Sent_date__c = Datetime.now()
        );
        Test.startTest();
        Assert.areEqual('Anne', STO_RecordInfoController.getReplyRecipientFirstName(thread.Id));
        Test.stopTest();
    }

    @IsTest
    static void selfAndLegacyThreadGreetingsKeepOwnContact() {
        Contact child = [SELECT Id, FirstName FROM Contact WHERE Account.LastName = 'Navnesen' LIMIT 1];
        Thread__c thread = new Thread__c(CRM_Thread_Type__c = 'STO', CRM_Contact__c = child.Id);
        insert thread;
        Test.startTest();
        Assert.areEqual(child.FirstName, STO_RecordInfoController.getReplyRecipientFirstName(thread.Id));
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Child starts own thread',
            CRM_From_Contact__c = child.Id,
            CRM_External_Message__c = true
        );
        Assert.areEqual(child.FirstName, STO_RecordInfoController.getReplyRecipientFirstName(thread.Id));
        Test.stopTest();
    }

    @IsTest
    static void unknownOriginalSenderDoesNotFallBackToChild() {
        Contact child = [SELECT Id FROM Contact WHERE Account.LastName = 'Navnesen' LIMIT 1];
        Thread__c thread = new Thread__c(CRM_Thread_Type__c = 'STO', CRM_Contact__c = child.Id);
        insert thread;
        Message__c unknownSender = new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Unknown original sender',
            CRM_External_Message__c = true
        );
        insert unknownSender;
        // The create-only flow derives external status from the contact; recreate a legacy missing-contact record.
        update new Message__c(Id = unknownSender.Id, CRM_External_Message__c = true);
        Test.startTest();
        Assert.areEqual('', STO_RecordInfoController.getReplyRecipientFirstName(thread.Id));
        try {
            STO_RecordInfoController.getReplyRecipientFirstName(null);
            Assert.fail('Missing thread must fail explicitly');
        } catch (AuraHandledException expected) {
            Assert.isNotNull(expected);
        }
        Test.stopTest();
    }
}

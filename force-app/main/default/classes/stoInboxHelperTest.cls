@isTest
public with sharing class stoInboxHelperTest {
    @TestSetup
    static void makeData() {
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678910'));
        STO_TestDataFactory.createRecord(
            new Person__c(Name = '12345678911', INT_Confidential__c = 'STRENGT_FORTROLIG')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Kontakt NAV', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Tema')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Spørsmål og Svar', CRM_Code__c = 'SPM_OG_SVR', CRM_Code_Set__c = 'Oppgavetyper')
        );
    }

    @isTest
    static void getThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker', personContact.AccountId, personContact.Id);
        t.CRM_Closed_Date__c = date.today(); 
        update t; 
        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    @isTest
    static void getRecentThreadsTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker', personContact.AccountId, personContact.Id);
        Test.startTest();
        List<stoInboxHelper.thread> tList = stoInboxHelper.getRecentThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    @isTest
    static void getLatestMessageTest() {
        Contact personContact = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = '12345678910'
            LIMIT 1
        ];
        Case c = stoHelperClass.createCase('Jobbsøker', null);
        Thread__c t = stoHelperClass.createThread(c.Id, 'Jobbsøker', personContact.AccountId, personContact.Id);
        stoHelperClass.createMessage(t, 'this is a test message again', personContact.Id);
        Test.startTest();
        stoInboxHelper.message m = stoInboxHelper.getLatestMessage(t.Id);
        Test.stopTest();
        System.assertEquals('this is a test message again', m.messageText);
    }
}



    
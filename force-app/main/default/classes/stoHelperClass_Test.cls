@isTest
public with sharing class stoHelperClass_Test {
   
    @TestSetup
    static void makeData(){
        
    }

    @isTest
    static void getThemesTest(){
        Test.startTest();
        List<STO_Category__mdt> themes = stoHelperClass.getThemes('no');
        List<STO_Category__mdt> themesen = stoHelperClass.getThemes('en-US');
        Test.stopTest();
        System.assertEquals(themes.isEmpty(), false, 'Missing metadata setup - initiate STO Category Themes');
    } 
    @isTest
    static void createCaseTest(){
        Test.startTest();
        Case c = stoHelperClass.createCase('Jobbsøker');
        Test.stopTest();
        System.assertEquals('Web', c.Origin, 'Incorrect case origin - check case creation');
    }
    @isTest
    static void createThreadCaseTest(){
        Case c = stoHelperClass.createCase('Jobbsøker');
        Test.startTest();
        Thread__c t = stoHelperClass.createThread(c, 'Jobbsøker');
        Test.stopTest();
        System.assertEquals(t.CRM_Related_Object__c, c.Id, 'Thread creation test failure, check thread');
    }
    @isTest
    static void createMessageTest(){
        Case c = stoHelperClass.createCase('Jobbsøker');  
        Thread__c t = stoHelperClass.createThread(c, 'Jobbsøker');
        Test.startTest();
        stoHelperClass.createMessage(t, 'this is a test message');
        Test.stopTest();
        List<Message__c> m = [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c =: t.Id];
        System.assertEquals('this is a test message', m.get(0).CRM_Message_Text__c);
    }
    @isTest
    static void getThreadsTest(){
        Case c = stoHelperClass.createCase('Jobbsøker');  
        Thread__c t = stoHelperClass.createThread(c, 'Jobbsøker');
        Test.startTest();
        List<Thread__c> tList = stoHelperClass.getThreads();
        Test.stopTest();
        System.assertEquals(tList.isEmpty(), false);
    }
    @isTest
    static void getLatestMessageTest(){
        Case c = stoHelperClass.createCase('Jobbsøker');  
        Thread__c t = stoHelperClass.createThread(c, 'Jobbsøker');
        stoHelperClass.createMessage(t, 'this is a test message again');
        Test.startTest();
        Message__c m = stoHelperClass.getLatestMessage(t.Id);
        Test.stopTest();
        System.assertEquals('this is a test message again', m.CRM_Message_Text__c);
    }
    @isTest
    static void createRequestTest(){
        Test.startTest();
        Id threadId = stoHelperClass.createRequest('Jobbsøker', 'This is the message');
        Test.stopTest();
        List<Message__c> msgList = [SELECT Id FROM Message__c WHERE CRM_Thread__c =: threadId];
        System.assertEquals(1, msgList.size());
        
    }

}

@isTest
public with sharing class stoUtilityBackgroundController_Test {
    @TestSetup
    static void makeData() {
        STO_TestDataFactory.createLiveChatTranscripts(1);
        STO_TestDataFactory.createPersons(1);
        STO_TestDataFactory.createCase('Test0');
    }

    @isTest
    static void nksUtilityBackgroundControllerTest() {
        LiveChatTranscript lct = [SELECT Id FROM LiveChatTranscript LIMIT 1];
        Case c = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        String tablabelchat = (String) stoUtilityBackgroundController.getTabName(lct.Id);
        String tablabelcase = (String) stoUtilityBackgroundController.getTabName(c.Id);
        Test.stopTest();

        System.assertEquals(
            null,
            tablabelchat,
            'Should be null because there is no chat button connected to the transcript'
        );
        System.assertEquals(null, tablabelcase, 'Should be null because there is no chat connected to the case');
    }

    @IsTest
    static void getOnlineIdTest() {
        Test.startTest();
        stoUtilityBackgroundController.getOnlineId();
        Test.stopTest();
    }
}

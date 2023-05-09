@isTest
public class STO_SurveyHelper_Test {
    @TestSetup
    static void makeData() {
        Account acc = (Account) STO_TestDataFactory.createRecord(new Account());
        Case casy = (Case) STO_TestDataFactory.createRecord(new Case(AccountId = acc.Id, Origin = 'STO'));
    }

    @isTest
    static void testGetSurveyLink() {
        Id caseId = [SELECT Id FROM Case LIMIT 1]?.Id;
        Test.startTest();
        String surveyLink = STO_SurveyHelper.getSurveyLink(caseId);
        Test.stopTest();
        System.assertEquals(null, surveyLink, 'Expected to return null.');
    }

    @isTest
    static void testGetURL() {
        String result = '';
        Test.startTest();
        try {
            result = STO_SurveyHelper.getURL();
        } catch (Exception e) {
            System.assertEquals(
                'NKS_SurveyController.SurveyException',
                e.getTypeName(),
                'Expected to throw SurveyException.'
            );
            System.assertEquals('Problem getting Base URL.', e.getMessage());
        }
        Test.stopTest();
        System.assertNotEquals(null, result, 'Expected to return Base URL.');
    }

    @isTest
    static void testCheckResponse() {
        Id caseId = [SELECT Id FROM Case LIMIT 1]?.Id;
        Test.startTest();
        Boolean completed = STO_SurveyHelper.checkResponse(caseId);
        Test.stopTest();
        System.assertEquals(false, completed, 'Expected to return false.');
    }
}

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
        String surveyLink;

        Test.startTest();
        try {
            surveyLink = STO_SurveyHelper.getSurveyLink(caseId);
        } catch (Exception e) {
            System.assertEquals(e.getMessage(), surveyLink, 'Returns exception as result.');
        }

        Test.stopTest();
    }

    @isTest
    static void testGenerateSurveyLink() {
        Id caseId = [SELECT Id FROM Case LIMIT 1]?.Id;

        Test.startTest();
        List<String> surveyLinks = STO_SurveyHelper.generateSurveyLink(new List<Id>{ caseId });
        Test.stopTest();

        System.assertEquals(1, surveyLinks.size(), 'List has one element (exception as link).');
    }
}

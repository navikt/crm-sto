@isTest
public class STO_SurveyHelper_Test {
    @isTest
    static void testCanSendSurvey() {
        Test.startTest();
        Boolean canSend = STO_SurveyHelper.canSendSurvey();
        Test.stopTest();

        System.assertEquals(true, canSend);
    }

    @isTest
    static void testGetSurveyLink() {
        Test.startTest();
        String surveyLink = STO_SurveyHelper.getSurveyLink();
        Test.stopTest();

        System.assertEquals(null, surveyLink);
    }
}

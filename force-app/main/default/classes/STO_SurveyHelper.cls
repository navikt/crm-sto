public without sharing class STO_SurveyHelper {
    @AuraEnabled(cacheable=true)
    public static String getSurveyLink(Id caseId) {
        return [SELECT InvitationLink FROM SurveyInvitation WHERE Name = :caseId LIMIT 1]?.InvitationLink;
    }

    @invocableMethod(label='Generate SurveyInvitationLink')
    public static List<String> generateSurveyLink(List<Id> caseIds) {
        List<String> surveyLinks = new List<String>();
        String surveyLink = '';
        if (Test.isRunningTest()) {
            surveyLink = 'testSurveyLink';
        }
        try {
            if (!Test.isRunningTest()) {
                Id surveyId = [SELECT Id, DeveloperName FROM Survey WHERE DeveloperName = 'nks_service_survey' LIMIT 1]
                ?.Id;
                surveyLink = NKS_SurveyController.createSurveyInvitation(surveyId, caseIds[0]);
            }
            surveyLinks.add(surveyLink);
        } catch (Exception e) {
            System.debug('Problem creating SurveyInvitationLink: ' + e.getMessage());
        }
        return surveyLinks;
    }

    @AuraEnabled(cacheable=true)
    public static string getURL() {
        return NKS_SurveyController.getBaseURL() + 's/completed';
    }

    @AuraEnabled(cacheable=true)
    public static Boolean checkResponse(Id caseId) {
        return NKS_SurveyController.checkSurveyResponse(caseId);
    }
}

public without sharing class STO_SurveyHelper {
    /**
     * @description Function to get InvitationLink for a Case
     * @param Id caseId
     * @return String InvitationLink
     */
    @AuraEnabled(cacheable=true)
    public static String getSurveyLink(Id caseId) {
        return [SELECT InvitationLink FROM SurveyInvitation WHERE Name = :caseId LIMIT 1]?.InvitationLink;
    }

    /**
     * @description Function to create SurveyInvitation
     * Calls function from Survey-repo
     * @param SurveyInvocableParameters parameters
     * @return String SurveyInvitationLink
     */
    public static String createSurveyInvitation(SurveyInvocableParameters parameters) {
        return NKS_SurveyController.createSurveyInvitation(parameters.surveyDeveloperName, parameters.caseId);
    }

    /**
     * @description Function to create survey link
     * @param List<SurveyInvocableParameters> parametersList
     * @return List<String> survey link
     */
    @invocableMethod(label='Generate SurveyInvitationLink')
    public static List<String> generateSurveyLink(List<SurveyInvocableParameters> parametersList) {
        List<String> surveyLinks = new List<String>();
        try {
            for (Integer i = 0; i < parametersList.size(); i++) {
                String surveyLink = createSurveyInvitation(parametersList[i]);
                surveyLinks.add(surveyLink);
            }
        } catch (Exception e) {
            System.debug('Problem creating SurveyInvitationLink: ' + e.getMessage());
        }
        return surveyLinks;
    }

    /**
     * @description Fucntion to get url for "Completed" community page (shows message that user has allready completed the survey.)
     * Calls function from Survey-repo
     * @return String url
     */
    @AuraEnabled(cacheable=true)
    public static string getURL() {
        return NKS_SurveyController.getBaseURL() + 's/completed';
    }

    /**
     * @description Function to check if user has allready respond to survey
     * Calls function from Survey-repo
     * @param Id caseId
     * @return Boolean True if a response exist, False otherwise
     */
    @AuraEnabled(cacheable=true)
    public static Boolean checkResponse(Id caseId) {
        return NKS_SurveyController.checkSurveyResponse(caseId);
    }

    /**
     * @description Class to define invocable variables
     */
    public class SurveyInvocableParameters {
        @InvocableVariable(required=true)
        public Id caseId;

        @InvocableVariable(required=true)
        public String surveyDeveloperName;
    }
}

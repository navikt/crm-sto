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
}

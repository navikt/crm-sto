public without sharing class STO_SurveyHelper {
    @AuraEnabled
    public static Boolean canSendSurvey() {
        return true;
    }

    @AuraEnabled
    public static String getSurveyLink() {
        return [
            SELECT Id, InvitationLink
            FROM SurveyInvitation
            WHERE
                OptionsAllowGuestUserResponse = TRUE
                AND IsDefault = TRUE
                AND Survey.DeveloperName = 'nks_service_survey'
            LIMIT 1
        ]
        ?.InvitationLink;
    }
}

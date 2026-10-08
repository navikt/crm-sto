public with sharing class CommunityLanguageSelectorUtility {
    /**
     * Method to be able to change the language easily in community
     */
    @AuraEnabled
    public static Boolean setLanguage(String language) {
        return setLanguageForUser(language, UserInfo.getUserId());
    }

    @TestVisible
    private static Boolean setLanguageForUser(String language, Id userId) {
        User u = new User(Id = userId);
        if (language.equals('Norwegian')) {
            u.LanguageLocaleKey = 'no';
        } else if (language.equals('English')) {
            u.LanguageLocaleKey = 'en_US';
        }
        try {
            update u;
            return true;
        } catch (DmlException e) {
            return false;
        }
    }

    @AuraEnabled
    public static String getLanguage() {
        return UserInfo.getLanguage();
    }
}

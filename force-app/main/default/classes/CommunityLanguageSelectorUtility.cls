public with sharing class CommunityLanguageSelectorUtility {
    /**
     * Method to be able to change the language easily in community
     */
    @AuraEnabled
    public static Boolean setLanguage(String language){
        Id uId = UserInfo.getUserId();
        User u = new User(Id = uId);
        if(language.equals('Norwegian')){
            u.LanguageLocaleKey = 'no';
        }
        else if(language.equals('English')){
            u.LanguageLocaleKey = 'en_US';
        }
        try{
            update u;
            return true;
        }
        catch(DmlException e){
            return false;
        }
    }
    /**
     * Done in Apex in order to avoid cacheing
     */
    @AuraEnabled
    public static string getLanguage(){
       String language = UserInfo.getLanguage();
       return language;
    }
}

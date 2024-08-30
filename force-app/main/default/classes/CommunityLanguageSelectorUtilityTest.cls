@isTest
public with sharing class CommunityLanguageSelectorUtilityTest {
    
    @isTest
    static void testSetLanguageSuccess() {
        String uniqueUserName = 'testuser' + System.currentTimeMillis() + '@example.com';
        
        User testUser = new User(
            LastName = 'Test',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US', // Default language
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUserName
        );
        insert testUser;
        
        System.runAs(testUser) {
            Boolean result = CommunityLanguageSelectorUtility.setLanguage('Norwegian');
            User updatedUser = [SELECT LanguageLocaleKey FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            Assert.isTrue(result, 'The setLanguage method should return true.');
            Assert.areEqual('no', updatedUser.LanguageLocaleKey, 'The LanguageLocaleKey should be set to Norwegian.');
        }
    }
    
    @isTest
    static void testGetLanguage() {
        String uniqueUserName = 'testuser' + System.currentTimeMillis() + '@example.com';
        User testUser = new User(
            LastName = 'Test',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUserName
        );
        insert testUser;
     
        System.runAs(testUser) {
            String language = CommunityLanguageSelectorUtility.getLanguage();
            Assert.areEqual('en_US', language, 'The getLanguage method should return the correct language key.');
        }
    }
}
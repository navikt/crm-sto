public with sharing class NKS_AmplitudeHelper {
    @AuraEnabled(cacheable=true)
    public static string getUserDepartment() {
        try {
            return [SELECT Department FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]?.Department;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting uesr department: ' + e.getMessage());
        }
    }
}

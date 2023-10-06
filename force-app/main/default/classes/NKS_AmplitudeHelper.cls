public with sharing class NKS_AmplitudeHelper {
    @AuraEnabled(cacheable=true)
    public static Properties getProperties() {
        try {
            return new properties(getAppName(), getUserDepartment());
        } catch (Exception e) {
            throw new AuraHandledException('Error gettting peroperties: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static string getUserDepartment() {
        try {
            return [SELECT Department FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]?.Department;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting uesr department: ' + e.getMessage());
        }
    }

    private static String getAppName() {
        try {
            UserAppInfo userAppInfo = [
                SELECT Id, AppDefinitionId
                FROM UserAppInfo
                WHERE UserId = :UserInfo.getUserId()
                LIMIT 1
            ];
            AppDefinition appDefinition = [
                SELECT DurableId, Label
                FROM AppDefinition
                WHERE DurableId = :userAppInfo.AppDefinitionId
                LIMIT 1
            ];
            return appDefinition.Label;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting App name: ' + e.getMessage());
        }
    }

    class Properties {
        @AuraEnabled
        public String appName;
        @AuraEnabled
        public String department;

        public Properties(String appName, String departement) {
            this.appName = appName;
            this.department = departement;
        }
    }
}

public with sharing class stoUtilityBackgroundController {
    @AuraEnabled
    public static string getTabName(String recordId) {
        try {
            String tabname;
            SObjectType objectName = Id.valueOf(recordId).getSobjectType();
            if (objectName == Schema.Case.getSObjectType()) {
                Case c = [SELECT STO_Category__c, Id, Origin FROM Case WHERE Id = :recordId LIMIT 1];
                if (c.STO_Category__c != null) {
                    tabname = c.STO_Category__c;
                }
            }
            return tabname;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string getOnlineId() {
        if (FeatureManagement.checkPermission('NKS_Beta')) {
            throw new AuraHandledException('BETA');
        } else {
            String statusId = String.valueOf(
                [SELECT Id FROM ServicePresenceStatus WHERE DeveloperName = 'Skriv_til_oss']
                ?.Id
            );
            return statusId.substring(0, 15);
        }
    }
}

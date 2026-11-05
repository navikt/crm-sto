/**
 * @description
 * Controller class to get related record
 */
public with sharing class STO_RecordInfoController {
    /**
     * @description
     * @author Stian Ruud Schikora | 09-14-2020
     * @param parentId [Id of the object to query to relation from]
     * @param relationshipField [API name of lookup field]
     * @param objectApiName [API name of parent]
     * @return sObject
     **/
    @AuraEnabled
    public static sObject getRelatedRecord(String parentId, String relationshipField, String objectApiName) {
        String query = 'SELECT ' + relationshipField + ' FROM ' + objectApiName;
        query += ' WHERE Id =\'' + parentId + '\'';

        List<SObject> records = Database.query(query);
        if (records.isEmpty()) {
            throw unavailableRecord();
        }
        return records[0];
    }

    @AuraEnabled
    public static string getThreadIdByApiReference(String apiRef) {
        return [SELECT Id FROM Thread__c WHERE CRM_API_Reference__c = :apiRef LIMIT 1]?.Id;
    }

    private static AuraHandledException unavailableRecord() {
        AuraHandledException error = new AuraHandledException('Vi kunne ikke hente posten.');
        error.setMessage('Vi kunne ikke hente posten.');
        return error;
    }
}

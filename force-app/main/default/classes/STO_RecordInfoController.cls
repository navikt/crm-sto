/**
 * @description
 * Controller class to get related record
 */
public class STO_RecordInfoController {
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

        sObject returnObject = Database.query(query)[0];

        return returnObject;
    }

    @AuraEnabled(cacheable=true)
    public static String getReplyRecipientFirstName(Id threadId) {
        // ToDo(backend): Authorize thread access and return the original sender's first name,
        // not the represented child's name. Keep the composer blocked until the recipient is verified.
        AuraHandledException error = new AuraHandledException('Reply recipient backend is not implemented yet.');
        error.setMessage('Reply recipient backend is not implemented yet.');
        throw error;
    }

    @AuraEnabled
    public static string getThreadIdByApiReference(String apiRef) {
        return [SELECT Id FROM Thread__c WHERE CRM_API_Reference__c = :apiRef LIMIT 1]?.Id;
    }
}

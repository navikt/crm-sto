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

    /**
     * @description Get the name of the unit with this unitnumber otherwise return an empty string.
     * @author Tor Håkon Sigurdsen
     * @param  unitNumber the number for the unit
     * @return the unit name or a blank string
     */
    @AuraEnabled
    public static String getUnitNameFromUnitNumber(String unitNumber) {
        if (String.isNotBlank(unitNumber)) {
            List<NavUnit__c> units = [SELECT Id, Name FROM NavUnit__c WHERE INT_UnitNumber__c = :unitNumber];

            if (units.size() > 0) {
                return units[0].Name;
            }
        }
        return '';
    }

    @AuraEnabled
    public static string getThreadIdByApiReference(String apiRef) {
        return [SELECT Id FROM Thread__c WHERE CRM_API_Reference__c = :apiRef LIMIT 1]?.Id;
    }
}

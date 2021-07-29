public without sharing class CRM_FlowFindCollection_WithoutSharing {
    public static list<sobject> CRM_FlowFindCollection_WithoutSharing(string soql, list<id> ListOfIds) {
        system.debug('CRM_FlowFindCollection_WithoutSharing');
        return Database.query(soql);
    }
}

public with sharing class relatedConversationNoteHelper {
    @AuraEnabled(cacheable=true)
    public static List<Conversation_Note__c> getRelatedConversations(
        String behandlingskjede,
        String behandlingsId,
        String apiRef
    ) {
        if (behandlingskjede == null || (behandlingsid == null && apiRef == null)) {
            return null;
        }
        List<Conversation_Note__c> related;
        if (behandlingskjede == behandlingsid || behandlingskjede == apiRef) {
            related = [
                SELECT Id, CRM_Date_Time_Registered__c
                FROM Conversation_Note__c
                WHERE
                    CRM_Henvendelse_BehandlingskjedeId__c = :behandlingskjede
                    AND ((CRM_Henvendelse_BehandlingsId__c != :behandlingsId
                    AND CRM_Henvendelse_BehandlingsId__c != NULL)
                    OR (CRM_API_Reference__c != :apiRef
                    AND CRM_API_Reference__c != NULL))
                ORDER BY CRM_Date_Time_Registered__c DESC
            ];
        } else {
            related = [
                SELECT Id, CRM_Date_Time_Registered__c
                FROM Conversation_Note__c
                WHERE CRM_Henvendelse_BehandlingsId__c = :behandlingskjede OR CRM_API_Reference__c = :behandlingskjede
                ORDER BY CRM_Date_Time_Registered__c DESC
            ];
        }
        return related;
    }
}

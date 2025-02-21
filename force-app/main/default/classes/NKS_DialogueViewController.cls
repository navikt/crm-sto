public with sharing class NKS_DialogueViewController {
    /**
     * Get a conversation note or thread by using the api reference as input
     * @author Stian Ruud Schikora | 05-26-2022
     * @param recordId
     * @return Id
     **/
    @AuraEnabled(cacheable=true)
    public static String getDialogueByApiReference(String reference) {
        Map<String, String> retMap = new Map<String, String>();
        try {
            List<List<SObject>> dialogs = [
                FIND :reference
                IN ALL FIELDS
                RETURNING Thread__c(Id), Conversation_Note__c(Id)
            ];
            return dialogs[0].size() > 0 ? JSON.serialize(dialogs[0][0]) : JSON.serialize(dialogs[1][0]);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Conversation_Note__c> getConvNote(Id convNoteId) {
        List<Conversation_Note__c> convNotes = [
            SELECT
                Id,
                CRM_Date_Time_Registered__c,
                CRM_Created_By_Ident__c,
                CRM_Created_By_NAV_Unit__c,
                CRM_Conversation_Note__c,
                CRM_Theme__r.Name,
                CRM_Journal_Status_Formula__c,
                CRM_Read_Date__c,
                CreatedById,
                Name,
                CRM_Registered_Datetime_Formula__c,
                CRM_Henvendelse_BehandlingskjedeId__c,
                CRM_Henvendelse_BehandlingsId__c,
                CRM_API_Reference__c,
                CRM_Theme_Group_Name__c
            FROM Conversation_Note__c
            WHERE Id = :convNoteId
        ];

        return convNotes;
    }
}

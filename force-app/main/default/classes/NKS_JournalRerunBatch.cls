public without sharing class NKS_JournalRerunBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
    private final static String fieldQuery = 'Select Id, CRM_Journal_Post_Type__c, CRM_Theme_Code__c , CRM_Conversation_Note__c, CRM_Created_By_Ident__c, CRM_Created_By_NAV_Unit__c, CRM_NAV_Case_Legacy_System__c, CRM_Thread__c, NAV_Case_Reference__c, Theme__c, CRM_Thread__r.CRM_Type__c, CRM_Subtheme_Code__c, Subtheme__c FROM Journal_Entry__c';
    private String queryFilter;
    private String externalReferenceSuffix;
    private final LoggerUtility logger = new LoggerUtility('Journal Rerun');

    @InvocableMethod(
        label='Initiate Journal rerun with externalReference suffix'
        description='Starts a process for rerunning journal entries to JOARK'
        category='Journal'
    )
    public static void initJournalBatcher(List<JournalRerunWrapper> inputs) {
        for (JournalRerunWrapper input : inputs) {
            if (input.scope == null || String.isBlank(input.scope)) {
                continue;
            }
            Database.executeBatch(new NKS_JournalRerunBatch(input.externalReferenceSuffix, input.scope), 20);
        }
    }

    public NKS_JournalRerunBatch(String externalReferenceSuffix, String queryFilter) {
        this.externalReferenceSuffix = externalReferenceSuffix;
        this.queryFilter = queryFilter;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = fieldQuery + ' WHERE ' + queryFilter;
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        processJournals((List<Journal_entry__c>) scope);
    }

    private void processJournals(List<Journal_entry__c> scope) {
        List<Journal_Entry__c> jEntriesToUpdate = new List<Journal_Entry__c>();
        for (Journal_entry__c jEntry : scope) {
            try {
                Map<String, Object> inputParameters = new Map<String, Object>();
                inputParameters.put('PERFORM_DML', false);
                inputParameters.put('externalReferenceSuffix', this.externalReferenceSuffix);
                inputParameters.put('Journal_Entry_SF', jEntry);

                Flow.Interview journalFlow;
                if (jEntry.CRM_Conversation_Note__c != null) {
                    journalFlow = Flow.Interview.createInterview('Journal_Conversation_Note_Retry', inputParameters);
                } else if (jEntry.CRM_Thread__c != null) {
                    if (jEntry.CRM_Thread__r.CRM_Type__c == 'CHAT') {
                        journalFlow = Flow.Interview.createInterview('CHAT_Journal_CHAT_Thread', inputParameters);
                    } else if (new List<String>{ 'STO', 'BTO', 'STB' }.contains(jEntry.CRM_Thread__r.CRM_Type__c)) {
                        journalFlow = Flow.Interview.createInterview('CRM_Journal_Message_Thread', inputParameters);
                    }
                }
                if (journalFlow == null) {
                    continue;
                }
                journalFlow.start();
                jEntriesToUpdate.add((Journal_Entry__c) journalFlow.getVariableValue('Journal_Entry_SF'));
            } catch (Exception e) {
                logger.error('Queued failed, exception: ' + e.getMessage(), jEntry, CRM_ApplicationDomain.Domain.NKS);
            }
        }
        List<Database.SaveResult> jEntryUpdRes = Database.update(jEntriesToUpdate, false);
        verifyUpdateResults(jEntryUpdRes);
        logger.publish();
    }

    private void verifyUpdateResults(List<Database.SaveResult> updResults) {
        for (Database.SaveResult updRes : updResults) {
            if (updRes.isSuccess()) {
                //Successfull update
            } else {
                String errorMsg = 'Failed to update record with id: ' + updRes.getId() + '\n';
                for (Database.Error err : updRes.getErrors()) {
                    errorMsg += err.getMessage() + '\n';
                }
                logger.error(errorMsg, null, CRM_ApplicationDomain.Domain.NKS);
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        logger.info('Done with NKS_JournalRerunBatch', null, CRM_ApplicationDomain.Domain.NKS);
        logger.publish();
    }

    public class JournalRerunWrapper {
        @invocableVariable(required=true)
        public String scope;
        @invocableVariable(required=true)
        public String externalReferenceSuffix;
    }
}

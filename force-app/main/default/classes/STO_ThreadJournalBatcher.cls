public without sharing class STO_ThreadJournalBatcher implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    private LoggerUtility logger = new LoggerUtility('Thread Journal Batch');
    private Boolean error = false;

    @InvocableMethod(
        label='Initiate Thread Journal Batch'
        description='Starts a process for posting journal entries to JOARK'
        category='Journal'
    )
    public static void initThreadJournalBatcher() {
        Database.executeBatch(new STO_ThreadJournalBatcher(), 50);
    }

    //################################################//
    //############ SELECTOR CLASS ####################//
    //################################################//

    private class JournalEntrySelector extends CRM_ApiSelector {
        public JournalEntrySelector() {
            super(false, false, false);
        }

        public List<Schema.SObjectField> getSObjectFieldList() {
            return new List<Schema.SObjectField>{
                Journal_Entry__c.Id,
                Journal_Entry__c.CRM_Thread__c,
                Journal_Entry__c.CRM_Created_By_Ident__c,
                Journal_Entry__c.CRM_Created_By_NAV_Unit__c,
                Journal_Entry__c.NAV_Case_Reference__c,
                Journal_Entry__c.CRM_Theme_Code__c,
                Journal_Entry__c.CRM_Subtheme_Code__c,
                Journal_Entry__c.Subtheme__c,
                Journal_Entry__c.Theme__c,
                Journal_Entry__c.CRM_NAV_Case_Legacy_System__c,
                Journal_Entry__c.CRM_Journal_Post_Type__c,
                Journal_Entry__c.Journal_Entry_Status__c
            };
        }

        public Schema.SObjectType getSObjectType() {
            return Journal_Entry__c.sObjectType;
        }

        private String getJournalConditions() {
            return 'CRM_Thread__r.CRM_isActive__c = false AND CRM_Thread__r.STO_Sensitive_Information__c = false AND CRM_Thread__r.CRM_Type__c IN (\'STO\', \'STB\', \'BTO\') AND Journal_Entry_Status__c = \'In Progress\'';
        }

        public String getJournalEntriesToJournal() {
            fflib_QueryFactory query = newQueryFactory();
            query.setCondition(getJournalConditions());

            return query.toSOQL();
        }
    }

    //################################################//
    //###### BATCH IMPLEMENTATION CLASS ##############//
    //################################################//

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(new JournalEntrySelector().getJournalEntriesToJournal());
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        List<Thread__c> threadsToUpdate = new List<Thread__c>();
        List<Journal_Entry__c> jEntriesToUpdate = new List<Journal_Entry__c>();
        Set<Id> processedThreadIds = new Set<Id>();

        for (Journal_Entry__c jEntry : (List<Journal_Entry__c>) scope) {
            jEntry.NAV_Case_Reference__c = jEntry.NAV_Case_Reference__c; //Self initialization for flow null handling
            jEntry.CRM_NAV_Case_Legacy_System__c = jEntry.CRM_NAV_Case_Legacy_System__c; //Self initialization for flow null handling
            Map<String, Object> flowInputs = new Map<String, Object>{
                'Journal_Entry_SF' => jEntry,
                'PERFORM_DML' => false
            };

            Flow.Interview journalFlow = Flow.Interview.createInterview('CRM_Journal_Message_Thread', flowInputs);
            journalFlow.start();
            jEntriesToUpdate.add((Journal_Entry__c) journalFlow.getVariableValue('Journal_Entry_SF'));
            if (processedThreadIds.contains(jEntry.CRM_Thread__c))
                continue; //Already added to list for update
            threadsToUpdate.add((Thread__c) journalFlow.getVariableValue('JOURNALED_THREAD'));
            processedThreadIds.add(jEntry.CRM_Thread__c);
        }

        List<Database.SaveResult> jEntryUpdRes = Database.update(jEntriesToUpdate, false);
        List<Database.SaveResult> threadUpdRes = Database.update(threadsToUpdate, false);

        verifyUpdateResults(jEntryUpdRes);
        verifyUpdateResults(threadUpdRes);
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
                this.error = true;
                logger.error(errorMsg, null, CRM_ApplicationDomain.Domain.NKS);
            }
        }
    }

    //If error occurred a critical log entry is logged that will publish automatically to slack
    public void finish(Database.BatchableContext BC) {
        if (this.error) {
            logger.critical('One of more records failed to update', null, CRM_ApplicationDomain.Domain.NKS); //Log a critical entry that should be published to slack for follow up;
            logger.publish();
        }
    }
}

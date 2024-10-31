public with sharing class nksJournalFeilregistrertQueueable implements Queueable, Database.AllowsCallouts {
    private String fieldQuery = 'Select CRM_Journal_Post_Type__c, CRM_Theme_Code__c , CRM_Conversation_Note__c, CRM_Created_By_Ident__c, CRM_Created_By_NAV_Unit__c, CRM_NAV_Case_Legacy_System__c, CRM_Thread__c, NAV_Case_Reference__c, Theme__c, CRM_Thread__r.CRM_Type__c, Theme__r.CRM_Code__c FROM Journal_Entry__c';
    private String queryFilter = 'Journal_Entry_ID__c != null AND ( ( CRM_Journal_Post_Type__c IN (\'UTGAAENDE\', \'INNGAAENDE\') AND CRM_Thread__r.CRM_Closed_Date__c >= 2024-10-18T11:30:00Z AND CRM_Thread__r.CRM_Closed_Date__c <= 2024-10-21T09:25:00Z AND CRM_Thread__r.CRM_Type__c IN (\'CHAT\', \'STB\') ) OR ( CRM_Conversation_note__c != null AND CreatedDate >= 2024-10-18T11:30:00Z AND CreatedDate <= 2024-10-21T09:25:00Z ) OR ( CRM_Journal_Post_Type__c IN (\'UTGAAENDE\', \'INNGAAENDE\') AND CRM_Thread__r.CRM_Type__c IN (\'STO\', \'BTO\', \'STB\') AND DAY_ONLY(CRM_Thread__r.CRM_Closed_Date__c) >= 2024-10-18 AND DAY_ONLY(CRM_Thread__r.CRM_Closed_Date__c) <= 2024-10-20 ))';
    private Database.Cursor locator;
    private integer position;
    private integer chunkSize = 20;
    private String externalReferenceSuffix = 'Rerun';
    private LoggerUtility logger = new LoggerUtility('Journal Rerun');

    public nksJournalFeilregistrertQueueable() {
        startQueue();
    }

    public nksJournalFeilregistrertQueueable(String externalReferenceSuffix) {
        this.externalReferenceSuffix = externalReferenceSuffix;
        startQueue();
    }

    public nksJournalFeilregistrertQueueable(String externalReferenceSuffix, String queryFilter) {
        if (externalReferenceSuffix != null) {
            this.externalReferenceSuffix = externalReferenceSuffix;
        }
        this.queryFilter = queryFilter;
        startQueue();
    }

    private void startQueue() {
        String query = fieldQuery + ' WHERE ' + queryFilter;
        if (!Test.isRunningTest()) {
            locator = Database.getCursor(query);
        }
        position = 0;
        System.enqueueJob(this);
    }

    public void execute(QueueableContext context) {
        List<Journal_entry__c> scope;
        if (Test.isRunningTest()) {
            scope = Database.query(fieldQuery);
        } else {
            Integer actualSize = Math.min(chunkSize, locator.getNumRecords() - position);
            scope = locator.fetch(position, actualSize);
            position += scope.size();
        }
        processJournals(scope);
    }

    private void processJournals(List<Journal_entry__c> scope) {
        for (Journal_entry__c jEntry : scope) {
            try {
                Map<String, Object> inputParameters = new Map<String, Object>();
                inputParameters.put('doReturnRecord', true);

                CRM_JournalEntryWrapper journalRequest;
                Id referenceId;
                if (jEntry.CRM_Conversation_Note__c != null) {
                    referenceId = jEntry.CRM_Conversation_Note__c;
                    inputParameters.put('recordId', jEntry.CRM_Conversation_Note__c);
                    inputParameters.put('Journal_Case_ID', jEntry.NAV_Case_Reference__c);
                    inputParameters.put('Journal_Case_Legacy_System', jEntry.CRM_NAV_Case_Legacy_System__c);
                    inputParameters.put('Journal_Entry_NAV_Ident', jEntry.CRM_Created_By_Ident__c);
                    inputParameters.put('Journal_Entry_Unit', jEntry.CRM_Created_By_NAV_Unit__c);
                    inputParameters.put('Journal_Theme_Code', jEntry.Theme__r.CRM_Code__c);
                    Flow.Interview.CRM_Journal_Conversation_Note_v_2 cNoteFlow = new Flow.Interview.CRM_Journal_Conversation_Note_v_2(
                        inputParameters
                    );
                    cNoteFlow.start();
                    journalRequest = (CRM_JournalEntryWrapper) cNoteFlow.getVariableValue('Journal_Request');
                } else if (jEntry.CRM_Thread__c != null) {
                    referenceId = jEntry.CRM_Thread__c;
                    inputParameters.put('Journal_Entry_SF', jEntry);
                    if (jEntry.CRM_Thread__r.CRM_Type__c == 'CHAT') {
                        Flow.Interview.CHAT_Journal_CHAT_Thread chatFlow = new Flow.Interview.CHAT_Journal_CHAT_Thread(
                            inputParameters
                        );
                        chatFlow.start();
                        journalRequest = (CRM_JournalEntryWrapper) chatFlow.getVariableValue('Journal_Request');
                    } else if (new List<String>{ 'STO', 'BTO', 'STB' }.contains(jEntry.CRM_Thread__r.CRM_Type__c)) {
                        Flow.Interview.CRM_Journal_Message_Thread threadFlow = new Flow.Interview.CRM_Journal_Message_Thread(
                            inputParameters
                        );
                        threadFlow.start();
                        journalRequest = (CRM_JournalEntryWrapper) threadFlow.getVariableValue('Journal_Request');
                    }
                }
                journalRequest.eksternReferanseId += this.externalReferenceSuffix;
                Blob checker = Blob.valueOf(JSON.serialize(journalRequest, true));
                // below converts blob to hexadecimal representation; four ones and zeros 
                // from blob will get converted to single hexadecimal character
                String hexString = EncodingUtil.convertToHex(checker);

                // One byte consists of eight ones and zeros so, one byte consists of two 
                // hex characters, hence the number of bytes would be
                Integer numOfBytes = hexString.length() / 2;
                if(numOfBytes < 4500) {
                    logger.error('Journal entry ' + jEntry.Id + ' resulted in a request of size ' + numOfBytes + ', aborting request. The full request was: \n' + JSON.serialize(journalRequest, true) + ' \nInputs were: ' + JSON.serialize(inputParameters, true),  null, CRM_ApplicationDomain.Domain.NKS);
                    jEntry.Journal_Entry_Status__c = 'Rerun Failed';
                    continue;
                }
                CRM_JournalUtilities.UtilityResponse resp = CRM_JournalUtilities.postJournal(
                    journalRequest,
                    referenceId,
                    jEntry.CRM_Created_By_Ident__c
                );

                jEntry.Journal_Entry_Status__c = resp.success ? 'Completed' : 'Rerun Failed';
                if (resp == null || resp.success == false) {
                    logger.error(
                        'Could not post rerun Journal, error: ' + resp.errorMessage,
                        jEntry,
                        CRM_ApplicationDomain.Domain.NKS
                    );
                } else {
                    if (resp.duplicate) {
                        jEntry.Journal_Entry_Status__c = 'Duplicate';
                    }
                    jEntry.Journal_Entry_ID__c = resp.journalpostId;
                }
            } catch (Exception e) {
                logger.error('Queued failed, exception: ' + e.getMessage(), jEntry, CRM_ApplicationDomain.Domain.NKS);
            }
        }
        update scope;
        logger.publish();
        if (!Test.isRunningTest() && position < locator.getNumRecords()) {
            System.enqueueJob(this);
        } else {
            logger.info('Done with nksJournalFeilregistrertQueueable', null, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
        }
    }
}

public with sharing class stoHelperClass {
    private static final String STO_CASE_RECORD_TYPE = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('STO_Case')
        .getRecordTypeId();
    private static final LoggerUtility logger = new LoggerUtility('Skriv til oss');

    private static Map<String, Id> commonCodeMap {
        get {
            if (commonCodeMap == null) {
                commonCodeMap = new Map<String, Id>();
                for (Common_Code__c comCode : [
                    SELECT Id, CRM_Code__c
                    FROM Common_Code__c
                    WHERE CRM_Code_Set__c IN ('Tema', 'Temagrupper', 'Oppgavetyper')
                ]) {
                    commonCodeMap.put(comCode.CRM_Code__c, comCode.Id);
                }
            }

            return commonCodeMap;
        }
        set {
        }
    }
    /**
     * Get themes from custom metadata
     * @Author Lars Petter Johnsen
     */
    @AuraEnabled(cacheable=true)
    public static List<STO_Category__mdt> getThemes(String language) {
        System.debug(language);
        String lang;
        if (language.equals('no')) {
            lang = 'Norwegian';
        } else if (language.equals('en-US')) {
            lang = 'English';
        }

        return [
            SELECT Id, Label, STO_Description__c, STO_Sort_Order__c, STO_Category__c
            FROM STO_Category__mdt
            WHERE STO_Language__c = :lang
            ORDER BY STO_Sort_Order__c ASC
        ];
    }
    /**
     * Method to create case, thread and message when a user submits a write to us case
     * @author Lars Petter Johnsen
     * @date 08.06.21
     */
    @AuraEnabled
    public static Id createRequest(String theme, String msgText) {
        String relatedObjId;
        Thread__c thread;

        User personUser = [
            SELECT
                AccountId,
                ContactId,
                Contact.Account.CRM_Person__r.INT_IsNavEmployee__c,
                Contact.Account.CRM_Person__r.INT_Confidential__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        if (isCaseRouting(personUser)) {
            //Create case Record and insert it
            relatedObjId = createCase(theme, personUser.AccountId).Id;
            thread = createThread(relatedObjId, theme, personUser);
        } else {
            thread = createThread(null, theme, personUser);
            relatedObjId = createNavTask(personUser.AccountId, thread.Id).Id;
            //Updates the thread relation in future context as the Thread ID is needed on the NAV Task NKS_Henvendelse_BehandlingsId__c for accessability through Gosys/Modia
            updateThreadRelation(thread.Id, relatedObjId);
        }
        createMessage(thread, msgText, personUser.ContactId);

        return thread.Id;
    }

    /**
     * @description: Defines logic if the incoming message should be routed via Case or if routing via NavTask__c is to be performed
     * @author Stian Ruud Schikora | 07-23-2021
     * @return Boolean
     **/
    private static Boolean isCaseRouting(User usr) {
        Boolean caseRouting = true;
        String confidentiality = String.isNotBlank(usr.Contact.Account.CRM_Person__r.INT_Confidential__c)
            ? usr.Contact.Account.CRM_Person__r.INT_Confidential__c
            : '';

        if (
            confidentiality.equalsIgnoreCase('STRENGT_FORTROLIG') ||
            confidentiality.equalsIgnoreCase('STRENGT_FORTROLIG_UTLAND')
        ) {
            caseRouting = false;
        }

        //Do necessary checks on confidential and NAV employee to determine the outcome
        return caseRouting;
    }

    /**
     * Creates a STO Case.
     * Invokes Assignment rules using DMLOptions
     * @author Lars Petter Johnsen
     * @Date 08.06.2021
     */
    @TestVisible
    private static Case createCase(String theme, String accountId) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.UseDefaultRule = true;

        Case casy = new Case();
        casy.Subject = 'Skriv til oss - ' + theme;
        casy.STO_Category__c = theme;
        casy.Origin = 'Web';
        casy.RecordTypeId = STO_CASE_RECORD_TYPE;

        casy.AccountId = accountId;

        //Invoke assignment rules
        casy.setOptions(dmlOpts);
        try {
            insert casy;
        } catch (DmlException e) {
            logger.exception(e);
            logger.publish();
        }
        return casy;
    }

    @testVisible
    private static NavTask__c createNavTask(String accountId, String threadId) {
        //Generate a NavTask that is to be routed via oppgave with the correct external reference to thread so that it can be viewed correctly in Modia
        NavTask__c newTask = new NavTask__c();
        newTask.CRM_Account__c = accountId;
        newTask.NKS_Theme__c = commonCodeMap.get('KNA');
        newTask.NKS_TaskType__c = commonCodeMap.get('SPM_OG_SVR');
        newTask.NKS_Comments__c = 'DEFAULT COMMENTS?';
        newTask.CRM_Priority__c = 'NORM';
        newTask.CRM_NavUnit__c = null; // Setting to null to trigger default task distribution
        newTask.NKS_Subtheme__c = null; // Need to include as flow fails if field is not defined
        newTask.NKS_Henvendelse_BehandlingsId__c = threadId;

        Map<String, Object> flowInputs = new Map<String, Object>{
            'NAV_Task' => newTask,
            'Created_By_Unit_Number' => null
        };

        //Performs the outbound call for submitting task to oppgave
        Flow.Interview taskFlow = Flow.Interview.createInterview('CRM_Send_NAV_Task_Auto', flowInputs);
        taskFlow.start();

        return (NavTask__c) taskFlow.getVariableValue('NAV_Task');
    }

    @future
    private static void updateThreadRelation(String threadId, String relatedObjId) {
        update new Thread__c(Id = threadId, CRM_Related_Object__c = relatedObjId);
    }

    private static Thread__c createThread(String relatedObjId, String theme, User personUser) {
        return createThread(relatedObjId, theme, personUser.AccountId, personUser.ContactId);
    }

    /**
     * Creates a thread to contain the STO conversation
     * @author Lars Petter Johnsen
     * @date 08.06.2021
     */
    @TestVisible
    private static Thread__c createThread(String relatedObjId, String theme, String accountId, String contactId) {
        Thread__c thread = new Thread__c();
        thread.CRM_Related_Object__c = relatedObjId;
        thread.CRM_Contact__c = contactId;
        thread.CRM_Account__c = accountId;
        thread.Name = 'Skriv til oss - ' + theme;
        try {
            insert thread;
        } catch (DmlException e) {
            logger.exception(e);
            logger.publish();
        }
        return thread;
    }
    @TestVisible
    private static void createMessage(Thread__c thread, String msgText, String contactId) {
        Message__c msg = new Message__c();
        msg.CRM_Message_Text__c = msgText;
        msg.CRM_From_Contact__c = contactId;
        msg.CRM_Thread__c = thread.Id;
        try {
            insert msg;
        } catch (DmlException e) {
            LoggerUtility logger = new LoggerUtility('Skriv til oss');
            logger.exception(e);
            logger.publish();
        }
    }
    /**
     * Method for accessing news regarding a STO Category
     * Returns a list of STO_News__C
     * @author Lars Petter Johnsen
     * @date 19.10.2021
     */

    @AuraEnabled(cacheable=true)
    public static List<STO_News__mdt> getCategoryNews(String category){
        List<STO_News__mdt> news = [SELECT STO_Body__c, STO_Header__c FROM STO_News__mdt WHERE STO_Category__c =: category];
        return news;
    }
}

public with sharing class stoHelperClass {
    private static final String STO_CASE_RECORD_TYPE = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('STO_Case')
        .getRecordTypeId();
    private static final LoggerUtility logger = new LoggerUtility('Skriv til oss');
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

        User personUser = [
            SELECT Account.CRM_Person__r.INT_IsNavEmployee__c, Account.CRM_Person__r.INT_Confidential__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        if (isCaseRouting(personUser)) {
            //Create case Record and insert it
            relatedObjId = createCase(theme, personUser.AccountId).Id;
        } else {
            relatedObjId = createNavTask(theme, personUser.AccountId).Id;
        }
        Thread__c thread = createThread(relatedObjId, theme);
        createMessage(thread, msgText);

        return thread.Id;
    }

    /**
     * @description: Defines logic if the incoming message should be routed via Case or if routing via NavTask__c is to be performed
     * @author Stian Ruud Schikora | 07-23-2021
     * @return Boolean
     **/
    private static Boolean isCaseRouting(User usr) {
        Boolean caseRouting = true;

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

    private static NavTask__c createNavTask(String theme, String accountId) {
        //Generate a NavTask that is to be routed via oppgave with the correct external reference to thread so that it can be viewed correctly in Modia
        //TODO expand with needed information for correct routing
        NavTask__c newTask = new NavTask__c();
        newTask.CRM_Account__c = accountId;
        return newTask;
    }

    /**
     * Creates a thread to contain the STO conversation
     * @author Lars Petter Johnsen
     * @date 08.06.2021
     */
    @TestVisible
    private static Thread__c createThread(String relatedObjId, String theme) {
        Thread__c thread = new Thread__c();
        thread.CRM_Related_Object__c = relatedObjId;
        thread.CRM_isPublic__c = true;
        thread.CRM_From__c = UserInfo.getUserId();
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
    private static void createMessage(Thread__c t, String msgText) {
        Message__c msg = new Message__c();
        msg.CRM_Message_Text__c = msgText;
        msg.CRM_From__c = UserInfo.getUserId();
        msg.CRM_Thread__c = t.Id;
        try {
            insert msg;
        } catch (DmlException e) {
            LoggerUtility logger = new LoggerUtility('Skriv til oss');
            logger.exception(e);
            logger.publish();
        }
    }
    /**
     * Get all threads. Utilize sharing sets to filter the correct messages
     * @Author Lars Petter
     */
    @AuraEnabled(cacheable=true)
    public static List<Thread__c> getThreads() {
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c
            FROM Thread__c
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        return threadList;
    }
    @AuraEnabled(cacheable=true)
    public static Message__c getLatestMessage(Id threadId) {
        List<Message__c> messageList = [
            SELECT Id, CRM_Message_Text__c, CRM_From__c
            FROM Message__c
            WHERE CRM_Thread__c = :threadId
            ORDER BY CreatedDate DESC
        ];

        return messageList.get(0);
    }
}

public with sharing class stoHelperClass {
    private static final LoggerUtility logger = new LoggerUtility('STO');

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

        return [SELECT Id, Label, STO_Category__c FROM STO_Category__mdt ORDER BY Id];
    }
    /**
     * Method to create case, thread and message when a user submits a write to us case. Case is created through flow on trigger.
     * @author Lars Petter Johnsen
     * @date 08.06.21
     */
    @AuraEnabled
    public static Thread__c createThreadWithCase(String theme, String msgText, Boolean medskriv, String type) {
        String relatedObjId;
        Thread__c thread;

        User personUser = [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId()];

        thread = createThread(null, theme, personUser, medskriv, type);
        createMessage(thread, msgText, personUser.ContactId);

        return thread;
    }

    private static Thread__c createThread(
        String relatedObjId,
        String theme,
        User personUser,
        Boolean medskriv,
        String type
    ) {
        return createThread(relatedObjId, theme, personUser.AccountId, personUser.ContactId, medskriv, type);
    }

    /**
     * Creates a thread to contain the STO conversation
     * @author Lars Petter Johnsen
     * @date 08.06.2021
     */
    @TestVisible
    private static Thread__c createThread(
        String relatedObjId,
        String theme,
        String accountId,
        String contactId,
        Boolean medskriv,
        String type
    ) {
        Thread__c thread = new Thread__c();
        thread.CRM_Related_Object__c = relatedObjId;
        thread.CRM_Contact__c = contactId;
        thread.CRM_Account__c = accountId;
        thread.Name = 'Skriv til oss';
        thread.CRM_Thread_Type__c = type;
        thread.STO_Category__c = theme;
        thread.STO_Medskriv__c = medskriv;
        try {
            insert thread;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
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
        msg.CRM_Read__c = true;
        msg.CRM_Read_Datetime__c = DateTime.now();
        try {
            insert msg;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
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
    public static List<STO_News__mdt> getCategoryNews(String category) {
        List<STO_News__mdt> news = [
            SELECT STO_Body__c, STO_Header__c
            FROM STO_News__mdt
            WHERE STO_Category__c = :category
        ];
        return news;
    }

    @AuraEnabled(cacheable=true)
    public static List<stoInboxHelper.thread> getOpenThreads(String category) {
        List<Thread__c> openThreads = [
            SELECT
                Id,
                LastModifiedDate,
                CRM_Number_of_unread_Messages__c,
                CRM_Latest_Message_Datetime__c,
                CRM_Closed_Date__c,
                STO_ExternalName__c,
                CRM_Is_Closed__c,
                CRM_Thread_Type__c,
                CRM_Related_Object__c,
                Name,
                (
                    SELECT Id, CRM_Message_Text__c, CRM_External_Message__c
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    ORDER BY CRM_Sent_Datetime_Formula__c DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE
                CRM_Is_Closed__C = FALSE
                AND CRM_Thread_Type__c IN ('STO', 'STB', 'BTO')
                AND STO_Category__c = :category
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        if (openThreads.size() > 0) {
            List<stoInboxHelper.thread> threadList = new List<stoInboxHelper.thread>();
            for (Thread__c t : openThreads) {
                threadList.add(stoInboxHelper.formatThread(t));
            }
            return threadList;
        }
        return null;
    }

    @AuraEnabled
    public static void closeThread(Id id) {
        try {
            if (id == null) {
                return;
            }
            Thread__c thread = new Thread__c(Id = id);
            thread.CRM_isActive__c = false;
            update thread;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
        }
    }
}

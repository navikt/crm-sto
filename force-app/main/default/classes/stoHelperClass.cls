public with sharing class stoHelperClass {
    private static final LoggerUtility logger = new LoggerUtility('STO');
    private static final List<String> allowedThreadTypes = new List<String>{ 'STO', 'BTO' };
    private static final Integer maxThreadCount = 3;
    private static final Map<String, List<String>> threadTypeMap = new Map<String, List<String>>{
        'STO' => new List<String>{ 'STO', 'STB' },
        'BTO' => new List<String>{ 'BTO' },
        'ALL' => new List<String>{ 'STO', 'STB', 'BTO' }
    };

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
        String lang;
        if (language.equals('no')) {
            lang = 'Norwegian';
        } else if (language.equals('en-US')) {
            lang = 'English';
        }

        return [SELECT Id, Label, STO_Category__c FROM STO_Category__mdt ORDER BY Id];
    }
    /**
     * Method to create case, thread and message when a user submits a write to us case. Case is created through
     * flow "On New STO Thread Create Task Or Case" on after-insert trigger.
     * @author Lars Petter Johnsen
     * @date 08.06.21
     */
    @AuraEnabled
    public static Thread__c createThreadWithCase(
        String theme,
        String msgText,
        Boolean medskriv,
        String type,
        String inboxTitle,
        String inboxTheme
    ) {
        String relatedObjId;
        Thread__c thread;

        if (isMaxThreadCount(theme, type)) {
            logger.error('Max thread limit reached in the same category', null, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
            throw new maxThreadLimitReachedException();
        }

        User personUser = [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        thread = createThread(null, theme, personUser, medskriv, type, inboxTitle, inboxTheme);
        createMessage(thread, msgText, personUser.ContactId);

        return thread;
    }

    private static Thread__c createThread(
        String relatedObjId,
        String theme,
        User personUser,
        Boolean medskriv,
        String type,
        String inboxTitle,
        String inboxTheme
    ) {
        return createThread(
            relatedObjId,
            theme,
            personUser.AccountId,
            personUser.ContactId,
            medskriv,
            type,
            inboxTitle,
            inboxTheme
        );
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
        String type,
        String inboxTitle,
        String inboxTheme
    ) {
        Thread__c thread = new Thread__c();
        thread.CRM_Related_Object__c = relatedObjId;
        thread.CRM_Contact__c = contactId;
        thread.CRM_Account__c = accountId;
        thread.Name = type == 'BTO' ? 'Beskjed til oss' : 'Skriv til oss';
        thread.CRM_Thread_Type__c = allowedThreadTypes.contains(type) ? type : 'STO';
        thread.STO_Category__c = theme;
        thread.STO_Medskriv__c = medskriv;
        thread.NKS_Inbox_Title__c = inboxTitle;
        thread.NKS_Inbox_Theme__c = inboxTheme;
        List<RecordType> recordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Thread__c' AND Name = 'NKS Thread'
            LIMIT 1
        ];
        if (!recordType.isEmpty()) {
            thread.recordTypeId = recordType[0].Id;
        }
        try {
            insert thread;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
            throw new threadOrMessageException();
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
            throw new threadOrMessageException();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<News> getNewsBasedOnTheme(String pageTitle, String pageTheme) {
        List<News> news = new List<News>();

        for (CRM_FAQ__c rec : [
            SELECT Id, CRM_Content__c, CRM_Title__c
            FROM CRM_FAQ__c
            WHERE CRM_Theme__c = :pageTheme AND CRM_Shown__c = :pageTitle
            ORDER BY CRM_Ordering__c ASC
        ]) {
            news.add(new News(rec.CRM_Title__c, rec.CRM_Content__c, rec.Id));
        }

        if (news.size() == 0 && Test.isRunningTest()) {
            news.add(new News('header test', 'body test', '123'));
        }
        return news;
    }

    public class News {
        @AuraEnabled
        public String header,
            body,
            id;
        public News(String header, String body, String id) {
            this.header = header;
            this.body = body;
            this.id = id;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<stoInboxHelper.thread> getOpenThreads(String category, String threadType) {
        List<String> allowedThreadTypes;
        if (threadTypeMap.keySet().contains(threadType)) {
            allowedThreadTypes = threadTypeMap.get(threadType);
        } else {
            allowedThreadTypes = threadTypeMap.get('ALL');
        }

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
                NKS_Inbox_Title__c,
                NKS_Inbox_Theme__c,
                (
                    SELECT Id, CRM_Message_Text__c, CRM_External_Message__c
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    ORDER BY CRM_Sent_Datetime_Formula__c DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE CRM_Is_Closed__C = FALSE AND CRM_Thread_Type__c IN :allowedThreadTypes AND STO_Category__c = :category
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

    private static Boolean isMaxThreadCount(String theme, String threadType) {
        List<String> allowedThreadTypes;
        if (threadTypeMap.keySet().contains(threadType)) {
            allowedThreadTypes = threadTypeMap.get(threadType);
        } else {
            allowedThreadTypes = threadTypeMap.get('ALL');
        }

        List<Thread__c> openThreads = [
                SELECT Id,
                (
                    SELECT Id
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    LIMIT 1
                )
                FROM Thread__c
                WHERE CRM_Is_Closed__C = FALSE AND STO_Category__c = :theme AND CRM_Thread_Type__c IN :allowedThreadTypes
            ];

        List<Thread__c> threadList = new List<Thread__c>();
        for (Thread__c t : openThreads) {
            if (t.Messages__r != null && t.Messages__r.size() > 0) {
                threadList.add(t);
            }
        }
        return threadList.size() >= maxThreadCount;
    }

    public class threadOrMessageException extends Exception {
    }

    public class maxThreadLimitReachedException extends Exception {
    }

    @AuraEnabled(cacheable=true)
    public static Thread__c getThread(String recordId) {
        return [
            SELECT
                Id,
                CRM_Thread_Type__c,
                STO_ExternalName__c,
                NKS_Inbox_Title__c,
                NKS_Inbox_Theme__c,
                CRM_Is_Closed__c,
                CRM_Related_Object__c
            FROM Thread__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
}

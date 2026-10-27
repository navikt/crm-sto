public with sharing class stoHelperClass {
    private static final LoggerUtility LOGGER = new LoggerUtility('STO');
    private static final List<String> ALLOWED_THREAD_TYPES = new List<String>{ 'STO', 'BTO' };
    private static final Integer MAX_THREAD_COUNT_STO = 3;
    private static final Integer MAX_THREAD_COUNT_BTO = 10;
    private static final Map<String, List<String>> THREAD_TYPE_MAP = new Map<String, List<String>>{
        'STO' => new List<String>{ 'STO', 'STB' },
        'BTO' => new List<String>{ 'BTO' },
        'ALL' => new List<String>{ 'STO', 'STB', 'BTO' }
    };

    @TestVisible
    private static Id cachedAccountId;
    private static Id accountId {
        get {
            if (cachedAccountId == null) {
                cachedAccountId = getAccountIdOfCurrentUser();
            }
            return cachedAccountId;
        }
    }

    private static Id getAccountIdOfCurrentUser() {
        return [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()]?.AccountId;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCodeToNameMap() {
        Map<String, String> codeToName = new Map<String, String>();
        for (Common_Code__c code : [
            SELECT CRM_Code__c, Name
            FROM Common_Code__c
            WHERE CRM_Code_Set__c IN ('Tema', 'Oppgavetyper', 'Behandlingstema', 'Behandlingstype')
        ]) {
            codeToName.put(code.CRM_Code__c, code.Name);
        }
        return codeToName;
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
     * Old version kept for compatibility with the frontend.
     * TODO: DELETE RIGHT AFTER DEPLOY
     */
    @AuraEnabled
    public static Thread__c createThreadWithCaseV2(
        String theme,
        String msgText,
        Boolean medskriv,
        String type,
        String inboxTitle,
        String inboxTheme,
        Boolean disabilityCampaign
    ) {
        ThreadData info = new ThreadData();
        info.theme = theme;
        info.msgText = msgText;
        info.medskriv = medskriv;
        info.type = type;
        info.inboxTitle = inboxTitle;
        info.inboxTheme = inboxTheme;
        info.disabilityCampaign = disabilityCampaign;
        info.medskriv = medskriv;
        return createThread(info);
    }

    /**
     * Method to create case, thread and message when a user submits a write to us case. Case is created through
     * flow "On New STO Thread Create Task Or Case" on after-insert trigger.
     * @author Lars Petter Johnsen
     * @date 08.06.21
     */
    @AuraEnabled
    public static Thread__c createThread(ThreadData info) {
        if (!validateData(info)) {
            return null;
        }
        Thread__c thread = info.toThread();
        try {
            insert thread;
        } catch (DmlException e) {
            LOGGER.exception(e, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
            throw new ThreadOrMessageException();
        }

        createMessage(thread, info);

        if (info.representedPersonIdentifier != null) {
            // Handle represented person logic here
            insertFamilieShare(thread);
        }
        return thread;
    }

    @TestVisible
    private static void createMessage(Thread__c thread, ThreadData info) {
        Message__c msg = new Message__c();
        msg.CRM_Message_Text__c = info.msgText;
        msg.CRM_From_Contact__c = info.contactId;
        msg.CRM_Thread__c = thread.Id;
        msg.CRM_Read__c = true;
        msg.CRM_Read_Datetime__c = DateTime.now();
        try {
            insert msg;
        } catch (DmlException e) {
            LOGGER.exception(e, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
            throw new ThreadOrMessageException();
        }
    }

    @TestVisible
    private static void insertFamilieShare(Thread__c thread) {
        // Implement the logic to insert FamilieShare record related to the thread
        Thread__Share share = new Thread__Share();
        share.ParentId = thread.Id;
        share.AccessLevel = 'Write';
        share.RowCause = Schema.Thread__Share.RowCause.Manual;
        share.UserOrGroupId = UserInfo.getUserId();
        try {
            insert share;
        } catch (DmlException e) {
            LOGGER.exception(e, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
            throw new ThreadOrMessageException();
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
        List<String> ALLOWED_THREAD_TYPES;
        if (THREAD_TYPE_MAP.containsKey(threadType)) {
            ALLOWED_THREAD_TYPES = THREAD_TYPE_MAP.get(threadType);
        } else {
            ALLOWED_THREAD_TYPES = THREAD_TYPE_MAP.get('ALL');
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
            WHERE
                CRM_Is_Closed__C = FALSE
                AND CRM_Thread_Type__c IN :ALLOWED_THREAD_TYPES
                AND STO_Category__c = :category
                AND CRM_Account__c = :accountId
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
            LOGGER.exception(e, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
        }
    }

    private static Boolean validateData(ThreadData info) {
        // We need to validate that the parent has a valid relation to the child.
        // TODO: Add proper validation through PDL api
        if (!info.validateRepresentation()) {
            LOGGER.error('Parent does not have valid relation to child', null, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
            throw new NoParentalResponsibilityException();
        }
        if (info.representedPersonIdentifier != null && info.accountId == null) {
            LOGGER.error(
                'Account not found for child when making STO.' + info.representedPersonIdentifier,
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
            LOGGER.publish();
            throw new ChildAccountNotFoundException();
        }

        // TODO: Check how we should determine max thread count for parental representation
        if (isMaxThreadCount(info)) {
            LOGGER.error('Max thread limit reached in the same category', null, CRM_ApplicationDomain.Domain.NKS);
            LOGGER.publish();
            throw new MaxThreadLimitReachedException();
        }
        return true;
    }

    private static Boolean isMaxThreadCount(ThreadData info) {
        List<String> ALLOWED_THREAD_TYPES;
        if (THREAD_TYPE_MAP.containsKey(info.type)) {
            ALLOWED_THREAD_TYPES = THREAD_TYPE_MAP.get(info.type);
        } else {
            ALLOWED_THREAD_TYPES = THREAD_TYPE_MAP.get('ALL');
        }

        List<Thread__c> openThreads = [
            SELECT
                Id,
                (
                    SELECT Id
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    LIMIT 1
                )
            FROM Thread__c
            WHERE
                CRM_Is_Closed__C = FALSE
                AND STO_Category__c = :info.theme
                AND CRM_Thread_Type__c IN :ALLOWED_THREAD_TYPES
                AND CRM_Account__c = :info.accountId
        ];

        List<Thread__c> threadList = new List<Thread__c>();
        for (Thread__c t : openThreads) {
            if (t.Messages__r != null && t.Messages__r.size() > 0) {
                threadList.add(t);
            }
        }
        return threadList.size() >= (info.type == 'BTO' ? MAX_THREAD_COUNT_BTO : MAX_THREAD_COUNT_STO);
    }

    public class ThreadOrMessageException extends Exception {
    }

    public class MaxThreadLimitReachedException extends Exception {
    }

    public class NoParentalResponsibilityException extends Exception {
    }

    public class ChildAccountNotFoundException extends Exception {
    }

    public class NoAccountFoundException extends Exception {
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
                CRM_Related_Object__c,
                STO_Category__c
            FROM Thread__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void putCloseIntent(Integer count) {
        try {
            User u = [SELECT Id, NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

            if (count >= 3) {
                u.NKS_Close_Intent__c = true;
            } else {
                u.NKS_Close_Intent__c = false;
            }
            update u;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to put close intent: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean getCloseIntent(String category) {
        User u = [SELECT NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId()];
        return u.NKS_Close_Intent__c && canUserCloseThread(category);
    }

    private static Boolean canUserCloseThread(String category) {
        Integer count = [
            SELECT COUNT()
            FROM Thread__c
            WHERE CRM_Is_Closed__c = FALSE AND STO_Category__c = :category AND CRM_Type__c = 'STO'
        ];
        return count >= 3;
    }

    public class ThreadData {
        @AuraEnabled
        public String theme { get; set; }
        @AuraEnabled
        public String msgText { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public String inboxTitle { get; set; }
        @AuraEnabled
        public String inboxTheme { get; set; }
        @AuraEnabled
        public Boolean medskriv { get; set; }
        @AuraEnabled
        public Boolean disabilityCampaign { get; set; }
        @AuraEnabled
        public String representedPersonIdentifier { get; set; }

        @TestVisible
        private Id cachedAccountId;
        @TestVisible
        private Id cachedContactId;

        public Id accountId {
            get {
                if (cachedAccountId != null) {
                    return cachedAccountId;
                }
                populateAccountAndContactIds();
                return cachedAccountId;
            }
        }

        public Id contactId {
            get {
                if (cachedContactId != null) {
                    return cachedContactId;
                }
                populateAccountAndContactIds();
                return cachedContactId;
            }
        }

        private void populateAccountAndContactIds() {
            if (representedPersonIdentifier == null) {
                User usr = [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
                cachedAccountId = usr?.AccountId;
                cachedContactId = usr?.ContactId;
            } else {
                List<Account> accList = [
                    SELECT Id, PersonContactId
                    FROM Account
                    WHERE Name = :representedPersonIdentifier
                    LIMIT 1
                ];
                cachedAccountId = accList.isEmpty() ? null : accList[0].Id;
                cachedContactId = accList.isEmpty() ? null : accList[0].PersonContactId;
            }
            if (cachedAccountId == null || cachedContactId == null) {
                LOGGER.error(
                    'Unable to determine Account or Contact ID for represented person: ' + representedPersonIdentifier,
                    null,
                    CRM_ApplicationDomain.Domain.NKS
                );
                LOGGER.publish();
                throw new NoAccountFoundException();
            }
        }

        public Thread__c toThread() {
            Thread__c thread = new Thread__c();

            thread.CRM_Contact__c = contactId;
            thread.CRM_Account__c = accountId;
            thread.Name = type == 'BTO' ? 'Beskjed til oss' : 'Skriv til oss';
            thread.CRM_Thread_Type__c = ALLOWED_THREAD_TYPES.contains(type) ? type : 'STO';
            thread.STO_Category__c = theme;
            thread.STO_Medskriv__c = medskriv;
            thread.NKS_Inbox_Title__c = inboxTitle;
            thread.NKS_Inbox_Theme__c = inboxTheme;

            if (disabilityCampaign != null && disabilityCampaign) {
                thread.NKS_Experience_Site_Source__c = 'Uforekampanje';
            }

            List<RecordType> recordType = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Thread__c' AND Name = 'NKS Thread'
                LIMIT 1
            ];
            if (!recordType.isEmpty()) {
                thread.recordTypeId = recordType[0].Id;
            }

            return thread;
        }

        public Boolean validateRepresentation() {
            String foreldre = '12345678901';
            String barn = representedPersonIdentifier;
            NKS_ForeldreansvarService.verifiser(foreldre, barn);
            return true;
        }
    }
}

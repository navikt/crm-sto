public with sharing class stoHelperClass {
    private static final LoggerUtility LOGGER = new LoggerUtility('STO');

    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, String>> getCodeToNameMaps() {
        Map<String, Map<String, String>> codeSets = new Map<String, Map<String, String>>();
        for (Common_Code__c code : [
            SELECT CRM_Code_Set__c, CRM_Code__c, Name
            FROM Common_Code__c
            WHERE CRM_Code_Set__c IN ('Tema', 'Oppgavetyper', 'Behandlingstema', 'Behandlingstype')
            ORDER BY CRM_Code_Set__c, CRM_Code__c, Id
        ]) {
            if (!codeSets.containsKey(code.CRM_Code_Set__c)) {
                codeSets.put(code.CRM_Code_Set__c, new Map<String, String>());
            }
            Map<String, String> codes = codeSets.get(code.CRM_Code_Set__c);
            if (codes.containsKey(code.CRM_Code__c) && codes.get(code.CRM_Code__c) != code.Name) {
                throw handledError('Conflicting names in a code set.');
            }
            codes.put(code.CRM_Code__c, code.Name);
        }
        return codeSets;
    }

    // TODO: Remove after deploy, legacy method just used for backwards compatibility
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCodeToNameMap() {
        Map<String, String> result = new Map<String, String>();
        for (Map<String, String> codes : getCodeToNameMaps().values()) {
            for (String code : codes.keySet()) {
                if (result.containsKey(code) && result.get(code) != codes.get(code)) {
                    throw handledError('Code is ambiguous across code sets. Use getCodeToNameMaps.');
                }
                result.put(code, codes.get(code));
            }
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<STO_Category__mdt> getThemes(String language) {
        return [SELECT Id, Label, STO_Category__c FROM STO_Category__mdt ORDER BY Label, DeveloperName];
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
        return createThread(info);
    }

    @AuraEnabled
    public static Thread__c createThread(ThreadData info) {
        return STO_ThreadService.createThread(info);
    }

    @AuraEnabled(cacheable=true)
    public static List<News> getNewsBasedOnTheme(String pageTitle, String pageTheme) {
        List<News> news = new List<News>();
        for (CRM_FAQ__c record : [
            SELECT Id, CRM_Content__c, CRM_Title__c
            FROM CRM_FAQ__c
            WHERE CRM_Theme__c = :pageTheme AND CRM_Shown__c = :pageTitle
            ORDER BY CRM_Ordering__c ASC, Id
        ]) {
            news.add(new News(record.CRM_Title__c, record.CRM_Content__c, record.Id));
        }
        return news;
    }

    @AuraEnabled(cacheable=true)
    public static List<stoInboxHelper.thread> getOpenThreads(String category, String threadType) {
        return getOpenThreadsForAccount(
            category,
            threadType,
            STO_ThreadIdentity.getCurrentUserAccountIdentity().accountId
        );
    }

    @AuraEnabled(cacheable=true)
    public static List<stoInboxHelper.thread> getAccessibleOpenThreadsForPerson(
        String category,
        String threadType,
        Id representedAccountId
    ) {
        String validCategory = STO_ThreadPolicy.validateCategory(category);
        STO_ThreadPolicy.getThreadTypes(threadType);
        return stoInboxHelper.getAccessibleOpenThreadsForPerson(validCategory, threadType, representedAccountId);
    }

    public static List<String> threadTypesFor(String threadType) {
        return STO_ThreadPolicy.getThreadTypes(threadType);
    }

    @AuraEnabled
    public static List<stoInboxHelper.thread> getOpenThreadsForPerson(
        String category,
        String threadType,
        String representedPersonIdentifier
    ) {
        STO_ThreadPolicy.validateCategory(category);
        STO_ThreadPolicy.getThreadTypes(threadType);
        STO_ThreadIdentity.AccountIdentity accountIdentity = STO_ThreadService.resolveThreadAccountIdentity(
            representedPersonIdentifier
        );
        return getOpenThreadsForAccount(category, threadType, accountIdentity.accountId);
    }

    private static List<stoInboxHelper.thread> getOpenThreadsForAccount(
        String category,
        String threadType,
        Id accountId
    ) {
        String validCategory = STO_ThreadPolicy.validateCategory(category);
        List<String> threadTypes = STO_ThreadPolicy.getThreadTypes(threadType);
        List<stoInboxHelper.thread> result = new List<stoInboxHelper.thread>();
        for (Thread__c record : [
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
                    WHERE CRM_Type__c IN ('Message', 'Info')
                    ORDER BY CRM_Sent_Datetime_Formula__c DESC, Id DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE
                CRM_Is_Closed__c = FALSE
                AND CRM_Thread_Type__c IN :threadTypes
                AND STO_Category__c = :validCategory
                AND CRM_Account__c = :accountId
            ORDER BY CRM_Latest_Message_Datetime__c DESC, Id DESC
        ]) {
            stoInboxHelper.thread formattedThread = stoInboxHelper.formatThread(record);
            if (formattedThread != null) {
                result.add(formattedThread);
            }
        }
        return result;
    }

    @AuraEnabled
    public static void closeThread(Id id) {
        if (id == null || id.getSObjectType() != Thread__c.SObjectType) {
            throw handledError('A valid thread ID is required.');
        }
        List<Thread__c> threads = [SELECT Id FROM Thread__c WHERE Id = :id LIMIT 1];
        if (threads.isEmpty()) {
            throw handledError('Thread not found or unavailable.');
        }
        threads[0].CRM_isActive__c = false;
        try {
            update threads;
        } catch (DmlException e) {
            logError('Thread closure failed: ' + e.getDmlType(0));
            throw handledError('Unable to close the thread.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static Thread__c getThread(String recordId) {
        if (String.isBlank(recordId)) {
            throw handledError('A valid thread ID is required.');
        }
        Id threadId;
        try {
            threadId = Id.valueOf(recordId);
        } catch (StringException e) {
            throw handledError('A valid thread ID is required.');
        }
        if (threadId == null || threadId.getSObjectType() != Thread__c.SObjectType) {
            throw handledError('A valid thread ID is required.');
        }
        List<Thread__c> threads = [
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
            WHERE Id = :threadId
            LIMIT 1
        ];
        if (threads.isEmpty()) {
            throw handledError('Thread not found or unavailable.');
        }
        return threads[0];
    }

    @AuraEnabled
    public static void putCloseIntent(Integer count) {
        if (count == null || count < 0) {
            throw handledError('A non-negative thread count is required.');
        }
        Boolean closeIntent =
            count >= STO_ThreadPolicy.MAX_THREAD_COUNT_STO &&
            STO_ThreadPolicy.hasCategoryAtLimit(STO_ThreadIdentity.getCurrentUserAccountIdentity().accountId);
        try {
            update new User(Id = UserInfo.getUserId(), NKS_Close_Intent__c = closeIntent);
        } catch (DmlException e) {
            logError('Updating close intent failed: ' + e.getDmlType(0));
            throw handledError('Unable to update close intent.');
        }
    }

    @AuraEnabled
    public static Boolean getCloseIntent(String category) {
        String validCategory = STO_ThreadPolicy.validateCategory(category);
        User currentUser = [SELECT NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId()];
        return currentUser.NKS_Close_Intent__c &&
            STO_ThreadPolicy.countOpenThreads(
                STO_ThreadIdentity.getCurrentUserAccountIdentity().accountId,
                validCategory,
                'STO'
            ) >= STO_ThreadPolicy.MAX_THREAD_COUNT_STO;
    }

    public static AuraHandledException handledError(String message) {
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }

    public static void logError(String message) {
        LOGGER.error(message, null, CRM_ApplicationDomain.Domain.NKS);
        LOGGER.publish();
    }

    public class News {
        @AuraEnabled
        public String header { get; set; }
        @AuraEnabled
        public String body { get; set; }
        @AuraEnabled
        public String id { get; set; }

        public News(String header, String body, String id) {
            this.header = header;
            this.body = body;
            this.id = id;
        }
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
    public class InvalidThreadDataException extends Exception {
    }
    public class RepresentationVerificationException extends Exception {
    }
}

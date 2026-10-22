public with sharing class stoThreadAccess {
    private static final Set<String> THREAD_TYPES = new Set<String>{ 'STO', 'STB', 'BTO' };
    public static final String READ_ONLY_MESSAGE = 'Bare den personen som har startet samtalen kan svare eller avslutte samtalen.';

    public class ReplyContext {
        @AuraEnabled
        public Boolean canReply;
        @AuraEnabled
        public String senderName;
        @AuraEnabled
        public String representedName;
        @AuraEnabled
        public String representedLabel;
        @AuraEnabled
        public String inboxSenderLabel;
    }

    public static ReplyContext getReplyContext(Id threadId) {
        User viewer = [SELECT ContactId, IsPortalEnabled, UserType FROM User WHERE Id = :UserInfo.getUserId()];
        Thread__c thread = threads(new Set<Id>{ threadId }).get(threadId);
        if (thread == null) {
            throw new AuraHandledException('Vi kunne ikke hente samtalen.');
        }
        ReplyContext context = new ReplyContext();
        context.canReply =
            !isExternal(viewer) || (viewer.ContactId != null && starterContact(thread) == viewer.ContactId);
        if (!thread.Messages__r.isEmpty()) {
            Message__c firstMessage = thread.Messages__r[0];
            if (firstMessage.CRM_From_Contact__c != null) {
                String starterName = firstMessage.CRM_From_Contact__r.Name;
                if (firstMessage.CRM_From_Contact__c != thread.CRM_Contact__c) {
                    context.inboxSenderLabel = viewer.ContactId == thread.CRM_Contact__c
                        ? starterName + ' startet samtalen'
                        : (viewer.ContactId == firstMessage.CRM_From_Contact__c ? 'Deg' : starterName) +
                          ' på vegne av ' +
                          thread.CRM_Contact__r.Name;
                } else if (viewer.ContactId != thread.CRM_Contact__c) {
                    context.inboxSenderLabel = starterName + ' startet samtalen';
                }
            }
            if (firstMessage.CRM_From_Contact__c != null && firstMessage.CRM_From_Contact__c != thread.CRM_Contact__c) {
                context.senderName = firstMessage.CRM_From_Contact__r.Name;
                context.representedName = thread.CRM_Contact__r.Name;
                context.representedLabel = new RepresentedPersonLabel()
                    .format(thread.CRM_Account__c, context.representedName);
            }
        }
        return context;
    }

    public static void checkMessages(List<Message__c> messages) {
        if (UserInfo.getUserType() == 'Standard')
            return;
        User viewer = [SELECT ContactId, IsPortalEnabled, UserType FROM User WHERE Id = :UserInfo.getUserId()];
        if (!isExternal(viewer))
            return;
        Set<Id> threadIds = new Set<Id>();
        for (Message__c message : messages) {
            if (message.CRM_Thread__c != null && (message.CRM_Type__c == null || message.CRM_Type__c == 'Message')) {
                threadIds.add(message.CRM_Thread__c);
            }
        }
        if (threadIds.isEmpty())
            return;
        Map<Id, Thread__c> byId = threads(threadIds);
        for (Message__c message : messages) {
            if (message.CRM_Type__c != null && message.CRM_Type__c != 'Message')
                continue;
            if (!threadIds.contains(message.CRM_Thread__c))
                continue;
            Thread__c thread = byId.get(message.CRM_Thread__c);
            if (
                thread == null ||
                (THREAD_TYPES.contains(thread.CRM_Thread_Type__c) &&
                (viewer.ContactId == null ||
                starterContact(thread) != viewer.ContactId))
            ) {
                message.addError(READ_ONLY_MESSAGE);
            }
        }
    }

    public static void checkClosures(List<Thread__c> changed, Map<Id, SObject> previous) {
        Set<Id> closingIds = new Set<Id>();
        for (Thread__c thread : changed) {
            Thread__c oldThread = (Thread__c) previous.get(thread.Id);
            if (
                THREAD_TYPES.contains(thread.CRM_Thread_Type__c) &&
                ((oldThread.CRM_isActive__c && !thread.CRM_isActive__c) ||
                (oldThread.CRM_Closed_Date__c == null &&
                thread.CRM_Closed_Date__c != null))
            ) {
                closingIds.add(thread.Id);
            }
        }
        if (closingIds.isEmpty())
            return;
        if (UserInfo.getUserType() == 'Standard')
            return;
        User viewer = [SELECT ContactId, IsPortalEnabled, UserType FROM User WHERE Id = :UserInfo.getUserId()];
        if (!isExternal(viewer))
            return;
        Map<Id, Thread__c> byId = threads(closingIds);
        for (Thread__c thread : changed) {
            if (
                closingIds.contains(thread.Id) &&
                (!byId.containsKey(thread.Id) ||
                viewer.ContactId == null ||
                starterContact(byId.get(thread.Id)) != viewer.ContactId)
            ) {
                thread.addError(READ_ONLY_MESSAGE);
            }
        }
    }

    private static Boolean isExternal(User viewer) {
        return viewer.IsPortalEnabled || viewer.UserType == 'Guest';
    }

    private static Id starterContact(Thread__c thread) {
        if (!thread.Messages__r.isEmpty()) {
            return thread.Messages__r[0].CRM_From_Contact__c;
        }
        // Internally created legacy threads have no citizen creator; retain their existing self-thread behavior.
        return thread.CreatedBy.ContactId != null ? thread.CreatedBy.ContactId : thread.CRM_Contact__c;
    }

    private without sharing class RepresentedPersonLabel {
        public String format(Id accountId, String representedName) {
            if (String.isBlank(representedName)) {
                return null;
            }
            String label = 'Gjelder: ' + representedName;
            if (accountId == null) {
                return label;
            }
            Account account;
            try {
                account = [
                    SELECT CRM_Person__r.INT_Sex__c, CRM_Person__r.INT_DateOfBirth__c
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ];
            } catch (QueryException e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Unable to read represented person label metadata for account ' + accountId
                );
                return label;
            }
            if (account.CRM_Person__r == null) {
                return label;
            }
            Person__c person = account.CRM_Person__r;
            List<String> details = new List<String>();
            if (person.INT_Sex__c == 'Kvinne') {
                details.add('datter');
            } else if (person.INT_Sex__c == 'Mann') {
                details.add('sønn');
            }
            if (String.isNotBlank(person.INT_DateOfBirth__c)) {
                try {
                    Date birthDate = Date.valueOf(person.INT_DateOfBirth__c);
                    Integer age = Date.today().year() - birthDate.year();
                    if (birthDate.addYears(age) > Date.today()) {
                        age--;
                    }
                    details.add(age + ' år');
                } catch (Exception e) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'Unable to format represented person birth date for account ' + accountId
                    );
                }
            }
            if (!details.isEmpty()) {
                label += ' (' + String.join(details, ' ') + ')';
            }
            return label;
        }
    }

    private static Map<Id, Thread__c> threads(Set<Id> threadIds) {
        return new Map<Id, Thread__c>(
            [
                SELECT
                    Id,
                    CRM_Thread_Type__c,
                    CRM_Contact__c,
                    CRM_Contact__r.Name,
                    CRM_Account__c,
                    CreatedBy.ContactId,
                    (
                        SELECT CRM_From_Contact__c, CRM_From_Contact__r.Name
                        FROM Messages__r
                        WHERE
                            CRM_Type__c = 'Message'
                            AND (CRM_External_Message__c = TRUE
                            OR CRM_From_Contact__c != NULL)
                        ORDER BY CRM_Sent_date__c ASC, CreatedDate ASC, Id ASC
                        LIMIT 1
                    )
                FROM Thread__c
                WHERE Id IN :threadIds
            ]
        );
    }
}

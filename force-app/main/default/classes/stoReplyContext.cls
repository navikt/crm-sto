public with sharing class stoReplyContext {
    public static final String READ_ONLY_MESSAGE = 'Bare den personen som har startet samtalen kan svare eller avslutte samtalen.';

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
    @AuraEnabled
    public Boolean isWritingForChild;
    @AuraEnabled
    public Boolean wasStartedOnBehalfOfOwner;

    @AuraEnabled(cacheable=true)
    public static stoReplyContext getReplyContext(Id threadId) {
        Thread__c thread = threadContexts(new Set<Id>{ threadId }).get(threadId);
        if (thread == null) {
            throw unavailableThread();
        }
        User viewer = stoPersonContext.currentUser();
        stoReplyContext context = new stoReplyContext();
        context.isWritingForChild = viewer.ContactId != null && viewer.ContactId != thread.CRM_Contact__c;
        context.wasStartedOnBehalfOfOwner = false;
        context.canReply = isReplyAllowed(viewer, thread);
        if (!thread.Messages__r.isEmpty()) {
            Message__c firstMessage = thread.Messages__r[0];
            context.inboxSenderLabel = senderLabel(viewer.ContactId, firstMessage);
            if (firstMessage.CRM_From_Contact__c != null && firstMessage.CRM_From_Contact__c != thread.CRM_Contact__c) {
                context.wasStartedOnBehalfOfOwner = true;
                context.senderName = firstMessage.CRM_From_Contact__r.Name;
                context.representedName = thread.CRM_Contact__r.Name;
                if (viewer.ContactId != thread.CRM_Contact__c) {
                    context.representedLabel = viewer.ContactId == firstMessage.CRM_From_Contact__c
                        ? new RepresentedPersonLabel().format(thread.CRM_Account__c, context.representedName)
                        : context.senderName + ' på vegne av ' + context.representedName;
                }
            }
        }
        return context;
    }

    @AuraEnabled(cacheable=true)
    public static String getReplyRecipientFirstName(Id threadId) {
        Thread__c thread = threadContexts(new Set<Id>{ threadId }).get(threadId);
        if (thread == null) {
            throw unavailableThread();
        }
        Id recipientId = originalSenderContactId(thread);
        if (recipientId == null) {
            return '';
        }
        List<Contact> recipients = [SELECT FirstName FROM Contact WHERE Id = :recipientId];
        if (recipients.isEmpty()) {
            AuraHandledException error = new AuraHandledException('Vi kunne ikke hente mottakeren av svaret.');
            error.setMessage('Vi kunne ikke hente mottakeren av svaret.');
            throw error;
        }
        return recipients[0].FirstName == null ? '' : recipients[0].FirstName;
    }

    public static Map<Id, String> inboxSenderLabels(Set<Id> threadIds) {
        Map<Id, String> labels = new Map<Id, String>();
        if (threadIds.isEmpty()) {
            return labels;
        }
        Id viewerContactId = stoPersonContext.currentUser().ContactId;
        for (Thread__c record : threadContexts(threadIds).values()) {
            labels.put(
                record.Id,
                senderLabel(viewerContactId, record.Messages__r.isEmpty() ? null : record.Messages__r[0])
            );
        }
        return labels;
    }

    public static void checkMessages(List<Message__c> messages) {
        if (UserInfo.getUserType() == 'Standard')
            return;
        Set<Id> threadIds = new Set<Id>();
        for (Message__c message : messages) {
            if (message.CRM_Thread__c != null && (message.CRM_Type__c == null || message.CRM_Type__c == 'Message')) {
                threadIds.add(message.CRM_Thread__c);
            }
        }
        if (threadIds.isEmpty())
            return;
        User viewer = stoPersonContext.currentUser();
        if (!isExternal(viewer))
            return;
        Map<Id, Thread__c> byId = threadContexts(threadIds);
        List<String> supportedTypes = stoHelperClass.threadTypesFor('ALL');
        for (Message__c message : messages) {
            if (message.CRM_Type__c != null && message.CRM_Type__c != 'Message')
                continue;
            if (!threadIds.contains(message.CRM_Thread__c))
                continue;
            Thread__c thread = byId.get(message.CRM_Thread__c);
            if (
                thread == null ||
                (supportedTypes.contains(thread.CRM_Thread_Type__c) && !isReplyAllowed(viewer, thread))
            ) {
                message.addError(READ_ONLY_MESSAGE);
            }
        }
    }

    public static void checkClosures(List<Thread__c> changed, Map<Id, SObject> previous) {
        Set<Id> closingIds = new Set<Id>();
        List<String> supportedTypes = stoHelperClass.threadTypesFor('ALL');
        for (Thread__c thread : changed) {
            Thread__c oldThread = (Thread__c) previous.get(thread.Id);
            if (
                supportedTypes.contains(thread.CRM_Thread_Type__c) &&
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
        User viewer = stoPersonContext.currentUser();
        if (!isExternal(viewer))
            return;
        Map<Id, Thread__c> byId = threadContexts(closingIds);
        for (Thread__c thread : changed) {
            if (closingIds.contains(thread.Id) && !isReplyAllowed(viewer, byId.get(thread.Id))) {
                thread.addError(READ_ONLY_MESSAGE);
            }
        }
    }

    private static Boolean isExternal(User viewer) {
        return viewer.IsPortalEnabled || viewer.UserType == 'Guest';
    }

    private static Boolean isReplyAllowed(User viewer, Thread__c thread) {
        return thread != null &&
            (!isExternal(viewer) || (viewer.ContactId != null && originalSenderContactId(thread) == viewer.ContactId));
    }

    private static Id originalSenderContactId(Thread__c thread) {
        if (!thread.Messages__r.isEmpty()) {
            return thread.Messages__r[0].CRM_From_Contact__c;
        }
        // Only threads without an original citizen message use the creator/legacy-contact fallback.
        return thread.CreatedBy.ContactId != null ? thread.CreatedBy.ContactId : thread.CRM_Contact__c;
    }

    private static Map<Id, Thread__c> threadContexts(Set<Id> threadIds) {
        Set<Id> requestedIds = threadIds.clone();
        requestedIds.remove(null);
        if (requestedIds.isEmpty()) {
            return new Map<Id, Thread__c>();
        }
        // Inserting the first message can change the original sender in this transaction; do not cache these records.
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
                WHERE Id IN :requestedIds
            ]
        );
    }

    private static String senderLabel(Id viewerContactId, Message__c firstMessage) {
        if (firstMessage?.CRM_From_Contact__c == null || viewerContactId == firstMessage.CRM_From_Contact__c) {
            return null;
        }
        return firstMessage.CRM_From_Contact__r.Name + ' startet samtalen';
    }

    private static AuraHandledException unavailableThread() {
        AuraHandledException error = new AuraHandledException('Vi kunne ikke hente samtalen.');
        error.setMessage('Vi kunne ikke hente samtalen.');
        return error;
    }

    private static AuraHandledException unavailableRepresentedPerson() {
        AuraHandledException error = new AuraHandledException(
            'Vi kunne ikke hente informasjon om personen samtalen gjelder.'
        );
        error.setMessage('Vi kunne ikke hente informasjon om personen samtalen gjelder.');
        return error;
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
            // The caller has checked thread access and original-sender identity; expose only the represented age.
            List<Account> accounts = [
                SELECT CRM_Person__r.INT_DateOfBirth__c
                FROM Account
                WHERE Id = :accountId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (accounts.isEmpty()) {
                throw unavailableRepresentedPerson();
            }
            String birthDateValue = accounts[0].CRM_Person__r?.INT_DateOfBirth__c;
            if (String.isNotBlank(birthDateValue)) {
                try {
                    label += ' (' + stoPersonContext.ageInYears(Date.valueOf(birthDateValue)) + ' år)';
                } catch (TypeException error) {
                    throw unavailableRepresentedPerson();
                }
            }
            return label;
        }
    }
}

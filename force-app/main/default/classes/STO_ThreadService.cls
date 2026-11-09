public with sharing class STO_ThreadService {
    public static Thread__c createThread(stoHelperClass.ThreadData info) {
        validateInput(info);
        String threadType = STO_ThreadPolicy.creationType(info.type);
        String category = STO_ThreadPolicy.validateCategory(info.theme);
        String representedIdentifier = info.representedPersonIdentifier;
        if (representedIdentifier != null && String.isBlank(representedIdentifier)) {
            stoHelperClass.logError('Thread creation rejected: represented person identifier is blank.');
            throw new stoHelperClass.InvalidThreadDataException('A represented person identifier is required.');
        }
        STO_ThreadIdentity.AccountIdentity threadAccountIdentity = resolveThreadAccountIdentity(representedIdentifier);
        Thread__c thread = toThread(info, threadAccountIdentity, threadType, category);

        STO_ThreadPolicy.lockAccount(threadAccountIdentity.accountId);
        if (
            STO_ThreadPolicy.countOpenThreads(threadAccountIdentity.accountId, category, threadType) >=
            STO_ThreadPolicy.maxThreadCount(threadType)
        ) {
            stoHelperClass.logError(
                'Thread creation rejected: maximum open thread count reached. Thread type: ' +
                    threadType +
                    ', limit: ' +
                    STO_ThreadPolicy.maxThreadCount(threadType) +
                    '.'
            );
            throw new stoHelperClass.MaxThreadLimitReachedException('Maximum open thread count reached.');
        }

        Savepoint savepoint = Database.setSavepoint();
        try {
            insert thread;
            insert new Message__c(
                CRM_Message_Text__c = info.msgText,
                CRM_From_Contact__c = threadAccountIdentity.contactId,
                CRM_Thread__c = thread.Id,
                CRM_Read__c = true,
                CRM_Read_Datetime__c = DateTime.now()
            );
            if (String.isNotBlank(representedIdentifier)) {
                new RepresentationSharing().grantSubmitterAccess(thread.Id);
            }
        } catch (DmlException e) {
            Database.rollback(savepoint);
            stoHelperClass.logError('Thread creation failed: ' + e.getDmlType(0));
            throw new stoHelperClass.ThreadOrMessageException('Unable to create the thread and its message.');
        }
        return thread;
    }

    public static STO_ThreadIdentity.AccountIdentity resolveThreadAccountIdentity(String representedIdentifier) {
        STO_ThreadIdentity.AccountIdentity currentUserAccountIdentity = STO_ThreadIdentity.getCurrentUserAccountIdentity();
        if (String.isBlank(representedIdentifier)) {
            return currentUserAccountIdentity;
        }
        if (String.isBlank(currentUserAccountIdentity.personIdentifier)) {
            stoHelperClass.logError('Current user person identifier is unavailable for representation verification.');
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        }
        verifyRepresentation(currentUserAccountIdentity.personIdentifier, representedIdentifier);
        return STO_ThreadIdentity.getRepresentedAccountIdentity(representedIdentifier);
    }

    // TODO: Change this to use the new verifyRepresentation method from the controller
    // which returns a boolean instead of the actual response.

    @TestVisible
    private static void verifyRepresentation(String parentIdentifier, String childIdentifier) {
        HttpResponse response;
        try {
            response = NKS_ForeldreansvarService.verifiser(parentIdentifier, childIdentifier);
        } catch (CalloutException e) {
            stoHelperClass.logError('Parental responsibility service call failed.');
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        } catch (NKS_ForeldreansvarService.ForeldreansvarException e) {
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        }
        if (response == null || response.getStatusCode() != 200) {
            stoHelperClass.logError(
                'Parental responsibility service returned an unexpected response. HTTP status: ' +
                    (response == null ? 'unavailable' : String.valueOf(response.getStatusCode())) +
                    '.'
            );
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        }
        RepresentationDecision decision;
        try {
            decision = (RepresentationDecision) JSON.deserialize(response.getBody(), RepresentationDecision.class);
        } catch (JSONException e) {
            stoHelperClass.logError('Parental responsibility service returned an invalid decision.');
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        }
        if (decision == null || decision.kanRepresentere == null) {
            stoHelperClass.logError('Parental responsibility service omitted its decision.');
            throw new stoHelperClass.RepresentationVerificationException('Unable to verify representation.');
        }
        if (!decision.kanRepresentere) {
            stoHelperClass.logError('Thread representation rejected: parental responsibility was not confirmed.');
            throw new stoHelperClass.NoParentalResponsibilityException('Parental responsibility was not confirmed.');
        }
    }

    private static void validateInput(stoHelperClass.ThreadData info) {
        if (info == null) {
            stoHelperClass.logError('Thread creation rejected: thread data is missing.');
            throw new stoHelperClass.InvalidThreadDataException('Thread data is required.');
        }
        if (String.isBlank(info.msgText) || info.msgText.length() > STO_ThreadPolicy.MAX_MESSAGE_LENGTH) {
            stoHelperClass.logError(
                'Thread creation rejected: message is blank or exceeds the length limit. Actual length: ' +
                    (info.msgText == null ? 0 : info.msgText.length()) +
                    ', maximum length: ' +
                    STO_ThreadPolicy.MAX_MESSAGE_LENGTH +
                    '.'
            );
            throw new stoHelperClass.InvalidThreadDataException('Received empty message or message is too long.');
        }
        if (info.medskriv == null) {
            stoHelperClass.logError('Thread creation rejected: training consent choice is missing.');
            throw new stoHelperClass.InvalidThreadDataException('Did not receive medskriv consent.');
        }
        Integer titleLength = info.inboxTitle == null ? 0 : info.inboxTitle.length();
        Integer themeLength = info.inboxTheme == null ? 0 : info.inboxTheme.length();
        Integer maxTitleLength = Thread__c.NKS_Inbox_Title__c.getDescribe().getLength();
        Integer maxThemeLength = Thread__c.NKS_Inbox_Theme__c.getDescribe().getLength();
        if (titleLength > maxTitleLength || themeLength > maxThemeLength) {
            stoHelperClass.logError(
                'Thread creation rejected: inbox title or theme exceeds the length limit. ' +
                    'inboxTitle length: ' +
                    titleLength +
                    ', maximum: ' +
                    maxTitleLength +
                    '; inboxTheme length: ' +
                    themeLength +
                    ', maximum: ' +
                    maxThemeLength +
                    '.'
            );
            throw new stoHelperClass.InvalidThreadDataException('Inbox title or theme is too long.');
        }
    }

    private static Thread__c toThread(
        stoHelperClass.ThreadData info,
        STO_ThreadIdentity.AccountIdentity accountIdentity,
        String threadType,
        String category
    ) {
        Schema.RecordTypeInfo recordType = Thread__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('NKS_Thread');
        if (recordType == null) {
            stoHelperClass.logError('NKS_Thread record type is missing.');
            throw new stoHelperClass.ThreadOrMessageException('Thread configuration is unavailable.');
        }
        return new Thread__c(
            CRM_Contact__c = accountIdentity.contactId,
            CRM_Account__c = accountIdentity.accountId,
            Name = threadType == 'BTO' ? 'Beskjed til oss' : 'Skriv til oss',
            CRM_Thread_Type__c = threadType,
            STO_Category__c = category,
            STO_Medskriv__c = info.medskriv,
            NKS_Inbox_Title__c = info.inboxTitle,
            NKS_Inbox_Theme__c = info.inboxTheme,
            NKS_Experience_Site_Source__c = info.disabilityCampaign == true ? 'Uforekampanje' : null,
            RecordTypeId = recordType.getRecordTypeId()
        );
    }

    private class RepresentationDecision {
        public Boolean kanRepresentere;
    }

    private without sharing class RepresentationSharing {
        public void grantSubmitterAccess(Id threadId) {
            Thread__c thread = [SELECT OwnerId FROM Thread__c WHERE Id = :threadId];
            if (thread.OwnerId != UserInfo.getUserId()) {
                insert new Thread__Share(
                    ParentId = threadId,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Thread__Share.RowCause.Manual,
                    UserOrGroupId = UserInfo.getUserId()
                );
            }
        }
    }
}

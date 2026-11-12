@IsTest
private class stoHelperClass_Test {
    @TestSetup
    static void makeData() {
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678910'));
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678911'));
        insert new List<Common_Code__c>{
            new Common_Code__c(Name = 'Kontakt NAV', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Tema'),
            new Common_Code__c(Name = 'Question', CRM_Code__c = 'SPM_OG_SVR', CRM_Code_Set__c = 'Oppgavetyper')
        };
        insert new List<CRM_FAQ__c>{
            new CRM_FAQ__c(
                CRM_Title__c = 'STO news',
                CRM_Content__c = 'STO content',
                CRM_Theme__c = 'Arbeid',
                CRM_Shown__c = 'Skriv til oss',
                CRM_Ordering__c = 1
            ),
            new CRM_FAQ__c(
                CRM_Title__c = 'BTO news',
                CRM_Content__c = 'BTO content',
                CRM_Theme__c = 'Sykepenger',
                CRM_Shown__c = 'Gi beskjed',
                CRM_Ordering__c = 1
            )
        };
    }

    private static Contact getContact(String personIdentifier) {
        return [
            SELECT Id, AccountId
            FROM Contact
            WHERE Account.CRM_Person__r.Name = :personIdentifier
            LIMIT 1
        ];
    }

    private static void setCurrentUserAccountIdentity(String personIdentifier) {
        Contact contact = getContact(personIdentifier);
        STO_ThreadIdentity.cachedCurrentUserAccountIdentity = new STO_ThreadIdentity.AccountIdentity(
            contact.AccountId,
            contact.Id,
            personIdentifier
        );
        STO_ThreadIdentity.cachedUserId = UserInfo.getUserId();
    }

    private static stoHelperClass.ThreadData getThreadData() {
        setCurrentUserAccountIdentity('12345678910');
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.theme = 'Arbeid';
        info.msgText = 'This is the message';
        info.medskriv = true;
        info.type = 'STO';
        info.inboxTitle = 'Skriv til oss';
        info.inboxTheme = 'Arbeid';
        return info;
    }

    private static stoHelperClass.ThreadData getRepresentationData() {
        stoHelperClass.ThreadData info = getThreadData();
        info.representedPersonIdentifier = '12345678911';
        return info;
    }

    private static void assertInvalid(stoHelperClass.ThreadData info) {
        try {
            stoHelperClass.createThread(info);
            Assert.fail('Expected invalid thread data to be rejected.');
        } catch (stoHelperClass.InvalidThreadDataException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void getAccessibleOpenThreadsRequiresPersonContextTest() {
        Id representedAccountId = getContact('12345678910').AccountId;
        Test.startTest();
        for (Id selectedAccountId : new List<Id>{ null, representedAccountId }) {
            try {
                stoHelperClass.getAccessibleOpenThreadsForPerson('Arbeid', 'STO', selectedAccountId);
                Assert.fail('An internal user without a Person Account must not use the citizen lookup.');
            } catch (AuraHandledException error) {
                Assert.areEqual('Du har ikke tilgang til samtalene for denne personen.', error.getMessage());
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void createThreadAndMessageForCurrentUser() {
        stoHelperClass.ThreadData info = getThreadData();
        Test.startTest();
        Thread__c thread = stoHelperClass.createThread(info);
        Assert.areEqual(0, Limits.getCallouts(), 'Self-service must not verify parental responsibility.');
        Test.stopTest();

        Thread__c saved = [
            SELECT CRM_Account__c, CRM_Contact__c, CRM_Thread_Type__c, STO_Category__c, RecordType.DeveloperName
            FROM Thread__c
            WHERE Id = :thread.Id
        ];
        Contact person = getContact('12345678910');
        Assert.areEqual(person.AccountId, saved.CRM_Account__c);
        Assert.areEqual(person.Id, saved.CRM_Contact__c);
        Assert.areEqual('STO', saved.CRM_Thread_Type__c);
        Assert.areEqual('Arbeid', saved.STO_Category__c);
        Assert.areEqual('NKS_Thread', saved.RecordType.DeveloperName);
        List<Message__c> messages = [
            SELECT CRM_Message_Text__c, CRM_From_Contact__c, CRM_Read__c, CRM_Read_Datetime__c
            FROM Message__c
            WHERE CRM_Thread__c = :thread.Id
        ];
        Assert.areEqual(1, messages.size());
        Assert.areEqual(info.msgText, messages[0].CRM_Message_Text__c);
        Assert.areEqual(person.Id, messages[0].CRM_From_Contact__c);
        Assert.isTrue(messages[0].CRM_Read__c);
        Assert.isNotNull(messages[0].CRM_Read_Datetime__c);
    }

    @IsTest
    static void legacyCreationStillWorks() {
        setCurrentUserAccountIdentity('12345678910');
        Thread__c thread = stoHelperClass.createThreadWithCaseV2(
            'Arbeid',
            'Legacy message',
            false,
            'STO',
            'Skriv til oss',
            'Arbeid',
            false
        );
        Assert.isNotNull(thread.Id);
    }

    @IsTest
    static void creationNormalizesCategoryAndDefaultType() {
        stoHelperClass.ThreadData info = getThreadData();
        info.type = null;
        info.theme = 'arbeid';
        Thread__c thread = stoHelperClass.createThread(info);
        Assert.areEqual('STO', thread.CRM_Thread_Type__c);
        Assert.areEqual('Arbeid', thread.STO_Category__c);
        Assert.areEqual('Skriv til oss', thread.Name);
    }

    @IsTest
    static void validatesRequiredAndSupportedInputsBeforeWriting() {
        assertInvalid(null);
        stoHelperClass.ThreadData info = getThreadData();
        info.msgText = ' ';
        assertInvalid(info);
        info.msgText = 'Valid message';
        info.medskriv = null;
        assertInvalid(info);
        info.medskriv = false;
        info.type = 'ALL';
        assertInvalid(info);
        info.type = 'STO';
        info.theme = 'Unknown category';
        assertInvalid(info);
        info.theme = 'Arbeid';
        info.inboxTitle = 'x'.repeat(256);
        assertInvalid(info);
        info.inboxTitle = null;
        info.representedPersonIdentifier = '';
        assertInvalid(info);
        info.representedPersonIdentifier = ' ';
        assertInvalid(info);
        Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
    }

    @IsTest
    static void messageLengthBoundary() {
        stoHelperClass.ThreadData info = getThreadData();
        info.msgText = 'x'.repeat(2001);
        assertInvalid(info);
        info.msgText = 'x'.repeat(2000);
        Thread__c thread = stoHelperClass.createThread(info);
        Message__c message = [SELECT CRM_Message_Text__c FROM Message__c WHERE CRM_Thread__c = :thread.Id];
        Assert.areEqual(2000, message.CRM_Message_Text__c.length());
    }

    @IsTest
    static void oversizedInboxFieldsAreLoggedWithoutTheirContents() {
        stoHelperClass.ThreadData info = getThreadData();
        Integer titleLimit = Thread__c.NKS_Inbox_Title__c.getDescribe().getLength();
        Integer themeLimit = Thread__c.NKS_Inbox_Theme__c.getDescribe().getLength();
        info.inboxTitle = 't'.repeat(titleLimit + 1);
        info.inboxTheme = 'h'.repeat(themeLimit + 1);
        Test.startTest();
        assertInvalid(info);
        Test.getEventBus().deliver();
        Test.stopTest();
        List<Application_Log__c> logs = [
            SELECT Log_Message__c, Pay_Load__c
            FROM Application_Log__c
            WHERE Category__c = 'STO'
        ];
        Boolean found = false;
        for (Application_Log__c log : logs) {
            if (log.Log_Message__c?.contains('inbox title or theme exceeds the length limit') == true) {
                found = true;
                Assert.isTrue(
                    log.Log_Message__c.contains('inboxTitle length: ' + (titleLimit + 1) + ', maximum: ' + titleLimit)
                );
                Assert.isTrue(
                    log.Log_Message__c.contains('inboxTheme length: ' + (themeLimit + 1) + ', maximum: ' + themeLimit)
                );
                Assert.isFalse(log.Log_Message__c.contains(info.inboxTitle));
                Assert.isFalse(log.Log_Message__c.contains(info.inboxTheme));
                Assert.isFalse(log.Log_Message__c.contains(info.msgText));
                Assert.isTrue(String.isBlank(log.Pay_Load__c) || log.Pay_Load__c == 'null');
            }
        }
        Assert.isTrue(found, 'The inbox field length failure must be logged.');
        Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
    }

    @IsTest
    static void inboxThemeLengthIsValidatedIndependently() {
        stoHelperClass.ThreadData info = getThreadData();
        info.inboxTheme = 'h'.repeat(Thread__c.NKS_Inbox_Theme__c.getDescribe().getLength() + 1);
        assertInvalid(info);
        Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
    }

    @IsTest
    static void disabilityCampaignMapping() {
        stoHelperClass.ThreadData info = getThreadData();
        info.disabilityCampaign = true;
        Thread__c campaignThread = stoHelperClass.createThread(info);
        info.disabilityCampaign = false;
        Thread__c ordinaryThread = stoHelperClass.createThread(info);
        info.disabilityCampaign = null;
        Thread__c unspecifiedThread = stoHelperClass.createThread(info);
        Map<Id, Thread__c> saved = new Map<Id, Thread__c>([SELECT NKS_Experience_Site_Source__c FROM Thread__c]);
        Assert.areEqual('Uforekampanje', saved.get(campaignThread.Id).NKS_Experience_Site_Source__c);
        Assert.isNull(saved.get(ordinaryThread.Id).NKS_Experience_Site_Source__c);
        Assert.isNull(saved.get(unspecifiedThread.Id).NKS_Experience_Site_Source__c);
    }

    @IsTest
    static void stoQuotaBoundaryAndCategoryIsolation() {
        stoHelperClass.ThreadData info = getThreadData();
        for (Integer i = 0; i < STO_ThreadPolicy.MAX_THREAD_COUNT_STO; i++) {
            stoHelperClass.createThread(info);
        }
        try {
            stoHelperClass.createThread(info);
            Assert.fail('Expected the fourth STO thread to be rejected.');
        } catch (stoHelperClass.MaxThreadLimitReachedException e) {
            Assert.areEqual(3, [SELECT COUNT() FROM Thread__c]);
        }
        info.theme = 'Pensjon';
        Assert.isNotNull(stoHelperClass.createThread(info).Id);
    }

    @IsTest
    static void btoQuotaBoundaryAndTypeIsolation() {
        stoHelperClass.ThreadData info = getThreadData();
        info.type = 'BTO';
        info.inboxTitle = 'Gi beskjed';
        for (Integer i = 0; i < STO_ThreadPolicy.MAX_THREAD_COUNT_BTO; i++) {
            Thread__c thread = stoHelperClass.createThread(info);
            Assert.areEqual('Beskjed til oss', thread.Name);
        }
        try {
            stoHelperClass.createThread(info);
            Assert.fail('Expected the eleventh BTO thread to be rejected.');
        } catch (stoHelperClass.MaxThreadLimitReachedException e) {
            Assert.areEqual(10, [SELECT COUNT() FROM Thread__c]);
        }
        info.type = 'STO';
        Assert.isNotNull(stoHelperClass.createThread(info).Id);
    }

    @IsTest
    static void quotaAndListingIgnoreThreadsWithoutMessages() {
        stoHelperClass.ThreadData info = getThreadData();
        Contact person = getContact('12345678910');
        insert new Thread__c(
            Name = 'Empty thread',
            CRM_Account__c = person.AccountId,
            CRM_Contact__c = person.Id,
            CRM_Thread_Type__c = 'STO',
            STO_Category__c = 'Arbeid'
        );
        Assert.areEqual(0, STO_ThreadPolicy.countOpenThreads(person.AccountId, 'Arbeid', 'STO'));
        Assert.areEqual(0, stoHelperClass.getOpenThreads('Arbeid', 'STO').size());
        stoHelperClass.createThread(info);
        Assert.areEqual(1, stoHelperClass.getOpenThreads('arbeid', 'STO').size());
    }

    @IsTest
    static void quotaIncludesStbAndExcludesClosedThreads() {
        stoHelperClass.ThreadData info = getThreadData();
        Thread__c thread = stoHelperClass.createThread(info);
        thread.CRM_Thread_Type__c = 'STB';
        update thread;
        Id accountId = getContact('12345678910').AccountId;
        Assert.areEqual(1, STO_ThreadPolicy.countOpenThreads(accountId, 'Arbeid', 'STO'));
        Assert.areEqual(0, STO_ThreadPolicy.countOpenThreads(accountId, 'Arbeid', 'BTO'));
        thread.CRM_Closed_Date__c = Date.today();
        update thread;
        Assert.areEqual(0, STO_ThreadPolicy.countOpenThreads(accountId, 'Arbeid', 'STO'));
    }

    @IsTest
    static void currentUserListingDoesNotIncludeAnotherAccount() {
        stoHelperClass.ThreadData info = getThreadData();
        stoHelperClass.createThread(info);
        setCurrentUserAccountIdentity('12345678911');
        Assert.areEqual(0, stoHelperClass.getOpenThreads('Arbeid', 'ALL').size());
        stoHelperClass.createThread(info);
        Assert.areEqual(1, stoHelperClass.getOpenThreads('Arbeid', null).size());
    }

    @IsTest
    static void representationApprovalUsesRepresentedAccount() {
        stoHelperClass.ThreadData info = getRepresentationData();
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, '{"kanRepresentere":true}'));
        Test.startTest();
        Thread__c thread = stoHelperClass.createThread(info);
        Test.stopTest();
        Contact child = getContact('12345678911');
        Assert.areEqual(child.AccountId, thread.CRM_Account__c);
        Assert.areEqual(child.Id, thread.CRM_Contact__c);
        Assert.areEqual(
            child.Id,
            [SELECT CRM_From_Contact__c FROM Message__c WHERE CRM_Thread__c = :thread.Id].CRM_From_Contact__c
        );
    }

    @IsTest
    static void representationDenialWithHttp200IsRejected() {
        stoHelperClass.ThreadData info = getRepresentationData();
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, '{"kanRepresentere":false}'));
        Test.startTest();
        try {
            stoHelperClass.createThread(info);
            Assert.fail('HTTP 200 does not imply representation approval.');
        } catch (stoHelperClass.NoParentalResponsibilityException e) {
            Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
        }
        Test.stopTest();
    }

    @IsTest
    static void representationRequiresAnExplicitDecision() {
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, '{}'));
        Test.startTest();
        try {
            STO_ThreadService.verifyRepresentation('12345678910', '12345678911');
            Assert.fail('Missing approval must be a technical error.');
        } catch (stoHelperClass.RepresentationVerificationException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void representationRejectsMalformedJson() {
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, 'not json'));
        Test.startTest();
        try {
            STO_ThreadService.verifyRepresentation('12345678910', '12345678911');
            Assert.fail('Malformed approval must be a technical error.');
        } catch (stoHelperClass.RepresentationVerificationException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void representationUnexpectedStatusIsNotParentalDenial() {
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(204, ''));
        Test.startTest();
        try {
            STO_ThreadService.verifyRepresentation('12345678910', '12345678911');
            Assert.fail('A service response without a decision must be a technical error.');
        } catch (stoHelperClass.RepresentationVerificationException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void representationQuotaUsesChildRatherThanParent() {
        stoHelperClass.ThreadData info = getThreadData();
        setCurrentUserAccountIdentity('12345678911');
        for (Integer i = 0; i < STO_ThreadPolicy.MAX_THREAD_COUNT_STO; i++) {
            stoHelperClass.createThread(info);
        }
        setCurrentUserAccountIdentity('12345678910');
        info.representedPersonIdentifier = '12345678911';
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, '{"kanRepresentere":true}'));
        Test.startTest();
        try {
            stoHelperClass.createThread(info);
            Assert.fail('A represented person at the quota must not receive another thread.');
        } catch (stoHelperClass.MaxThreadLimitReachedException e) {
            Assert.areEqual(3, [SELECT COUNT() FROM Thread__c]);
        }
        Test.stopTest();
    }

    @IsTest
    static void unknownRepresentedAccountHasSpecificError() {
        try {
            STO_ThreadIdentity.getRepresentedAccountIdentity('12345678999');
            Assert.fail('Expected the missing represented account to be rejected.');
        } catch (stoHelperClass.ChildAccountNotFoundException e) {
            Assert.isFalse(e.getMessage().contains('12345678999'));
        }
    }

    @IsTest
    static void changingRequestIdentifierDoesNotReuseResolvedIdentity() {
        stoHelperClass.ThreadData data = new stoHelperClass.ThreadData();
        data.representedPersonIdentifier = '12345678910';
        STO_ThreadIdentity.AccountIdentity firstAccountIdentity = STO_ThreadIdentity.getRepresentedAccountIdentity(
            data.representedPersonIdentifier
        );
        data.representedPersonIdentifier = '12345678911';
        STO_ThreadIdentity.AccountIdentity secondAccountIdentity = STO_ThreadIdentity.getRepresentedAccountIdentity(
            data.representedPersonIdentifier
        );
        Assert.areNotEqual(firstAccountIdentity.accountId, secondAccountIdentity.accountId);
        Assert.areNotEqual(firstAccountIdentity.contactId, secondAccountIdentity.contactId);
    }

    @IsTest
    static void missingCurrentUserAccountFailsWithoutRecursion() {
        STO_ThreadIdentity.cachedCurrentUserAccountIdentity = new STO_ThreadIdentity.AccountIdentity(null, null, null);
        STO_ThreadIdentity.cachedUserId = UserInfo.getUserId();
        try {
            STO_ThreadIdentity.getCurrentUserAccountIdentity();
            Assert.fail('A current user without an account must be rejected.');
        } catch (stoHelperClass.NoAccountFoundException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void identityCacheIsScopedToCurrentUser() {
        setCurrentUserAccountIdentity('12345678910');
        STO_ThreadIdentity.cachedUserId = UserInfo.getOrganizationId();
        User currentUser = [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId()];
        if (currentUser.AccountId == null || currentUser.ContactId == null) {
            try {
                STO_ThreadIdentity.getCurrentUserAccountIdentity();
                Assert.fail('An identity cached for another user must not be used.');
            } catch (stoHelperClass.NoAccountFoundException e) {
                Assert.isNotNull(e.getMessage());
            }
        } else {
            STO_ThreadIdentity.AccountIdentity accountIdentity = STO_ThreadIdentity.getCurrentUserAccountIdentity();
            Assert.areEqual(currentUser.AccountId, accountIdentity.accountId);
            Assert.areEqual(currentUser.ContactId, accountIdentity.contactId);
        }
        Assert.areEqual(UserInfo.getUserId(), STO_ThreadIdentity.cachedUserId);
    }

    @IsTest
    static void identityRejectsBlankRepresentedIdentifier() {
        try {
            STO_ThreadIdentity.getRepresentedAccountIdentity(' ');
            Assert.fail('A blank identifier must not fall back to the current user.');
        } catch (stoHelperClass.InvalidThreadDataException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void failedCreationRollsBackItsWrites() {
        stoHelperClass.ThreadData info = getThreadData();
        Contact person = getContact('12345678910');
        STO_ThreadIdentity.cachedCurrentUserAccountIdentity = new STO_ThreadIdentity.AccountIdentity(
            person.AccountId,
            UserInfo.getUserId(),
            '12345678910'
        );
        Integer threadCount = [SELECT COUNT() FROM Thread__c];
        Integer messageCount = [SELECT COUNT() FROM Message__c];
        try {
            stoHelperClass.createThread(info);
            Assert.fail('An invalid contact reference must fail creation.');
        } catch (stoHelperClass.ThreadOrMessageException e) {
            Assert.areEqual('Unable to create the thread and its message.', e.getMessage());
        }
        Assert.areEqual(threadCount, [SELECT COUNT() FROM Thread__c]);
        Assert.areEqual(messageCount, [SELECT COUNT() FROM Message__c]);
    }

    @IsTest
    static void representedListingChecksApprovalAndAccountScope() {
        stoHelperClass.ThreadData info = getThreadData();
        setCurrentUserAccountIdentity('12345678911');
        Thread__c representedThread = stoHelperClass.createThread(info);
        setCurrentUserAccountIdentity('12345678910');
        stoHelperClass.createThread(info);
        Test.setMock(HttpCalloutMock.class, new RepresentationMock(200, '{"kanRepresentere":true}'));
        Test.startTest();
        List<stoInboxHelper.thread> threads = stoHelperClass.getOpenThreadsForPerson('Arbeid', 'STO', '12345678911');
        Test.stopTest();
        Assert.areEqual(1, threads.size());
        Assert.areEqual(representedThread.Id, threads[0].recordId);
    }

    @IsTest
    static void closeThreadPersistsClosure() {
        Thread__c thread = stoHelperClass.createThread(getThreadData());
        Test.startTest();
        stoHelperClass.closeThread(thread.Id);
        Test.stopTest();
        Thread__c saved = [SELECT CRM_isActive__c, CRM_Is_Closed__c FROM Thread__c WHERE Id = :thread.Id];
        Assert.isFalse(saved.CRM_isActive__c);
        Assert.isTrue(saved.CRM_Is_Closed__c, 'Closure must agree with the fields used for listing and quotas.');
    }

    @IsTest
    static void closeThreadRejectsMissingId() {
        try {
            stoHelperClass.closeThread(null);
            Assert.fail('Expected invalid closure input to fail explicitly.');
        } catch (AuraHandledException e) {
            Assert.areEqual('A valid thread ID is required.', e.getMessage());
        }
    }

    @IsTest
    static void threadLookupAndInvalidInputs() {
        Thread__c thread = stoHelperClass.createThread(getThreadData());
        Assert.areEqual(thread.Id, stoHelperClass.getThread(thread.Id).Id);
        for (String invalidId : new List<String>{ null, 'invalid', String.valueOf(UserInfo.getUserId()) }) {
            try {
                stoHelperClass.getThread(invalidId);
                Assert.fail('Expected invalid lookup input to fail explicitly.');
            } catch (AuraHandledException e) {
                Assert.areEqual('A valid thread ID is required.', e.getMessage());
            }
        }
        delete thread;
        try {
            stoHelperClass.getThread(thread.Id);
            Assert.fail('Expected a missing thread to fail explicitly.');
        } catch (AuraHandledException e) {
            Assert.areEqual('Thread not found or unavailable.', e.getMessage());
        }
    }

    @IsTest
    static void closeIntentDoesNotTrustClientCount() {
        setCurrentUserAccountIdentity('12345678910');
        stoHelperClass.putCloseIntent(100);
        Assert.isFalse([SELECT NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId()].NKS_Close_Intent__c);
        stoHelperClass.putCloseIntent(0);
        Assert.isFalse(stoHelperClass.getCloseIntent('Arbeid'));
        for (Integer invalidCount : new List<Integer>{ null, -1 }) {
            try {
                stoHelperClass.putCloseIntent(invalidCount);
                Assert.fail('Expected invalid close-intent input to fail explicitly.');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void closeIntentUsesAccountAndCategoryScope() {
        stoHelperClass.ThreadData info = getThreadData();
        for (Integer i = 0; i < STO_ThreadPolicy.MAX_THREAD_COUNT_STO; i++) {
            stoHelperClass.createThread(info);
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            stoHelperClass.putCloseIntent(3);
            Assert.isTrue(stoHelperClass.getCloseIntent('Arbeid'));
            Assert.isFalse(stoHelperClass.getCloseIntent('Pensjon'));
            setCurrentUserAccountIdentity('12345678911');
            Assert.isFalse(stoHelperClass.getCloseIntent('Arbeid'));
            stoHelperClass.putCloseIntent(3);
            Assert.isFalse([SELECT NKS_Close_Intent__c FROM User WHERE Id = :UserInfo.getUserId()].NKS_Close_Intent__c);
        }
    }

    @IsTest
    static void themesAcceptNullLanguageAndKeepAvailableCategories() {
        List<STO_Category__mdt> themes = stoHelperClass.getThemes(null);
        Assert.isFalse(themes.isEmpty());
        Assert.areEqual(themes.size(), stoHelperClass.getThemes('no').size());
        Assert.areEqual(themes.size(), stoHelperClass.getThemes('en-US').size());
    }

    @IsTest
    static void faqUsesRealDataAndEmptyResultsStayEmpty() {
        List<stoHelperClass.News> stoNews = stoHelperClass.getNewsBasedOnTheme('Skriv til oss', 'Arbeid');
        Assert.areEqual(1, stoNews.size());
        Assert.areEqual('STO news', stoNews[0].header);
        Assert.areEqual('STO content', stoNews[0].body);
        Assert.isNotNull(stoNews[0].id);
        List<stoHelperClass.News> btoNews = stoHelperClass.getNewsBasedOnTheme('Gi beskjed', 'Sykepenger');
        Assert.areEqual(1, btoNews.size());
        Assert.areEqual('BTO news', btoNews[0].header);
        Assert.areEqual(0, stoHelperClass.getNewsBasedOnTheme('Skriv til oss', 'Missing theme').size());
    }

    @IsTest
    static void codeMapsPreserveCodeSetBoundaries() {
        Assert.areEqual('Kontakt NAV', stoHelperClass.getCodeToNameMap().get('KNA'));
        insert new Common_Code__c(Name = 'Different name', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Oppgavetyper');
        Map<String, Map<String, String>> maps = stoHelperClass.getCodeToNameMaps();
        Assert.areEqual('Kontakt NAV', maps.get('Tema').get('KNA'));
        Assert.areEqual('Different name', maps.get('Oppgavetyper').get('KNA'));
        try {
            stoHelperClass.getCodeToNameMap();
            Assert.fail('The legacy map must not silently overwrite an ambiguous code.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('ambiguous'));
        }
    }

    // TODO: Replace the method above after removing the legacy getCodeToNameMap method.
    /*
    @IsTest
    static void codeMapsPreserveCodeSetBoundaries() {
        insert new Common_Code__c(Name = 'Different name', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Oppgavetyper');
        Map<String, Map<String, String>> maps = stoHelperClass.getCodeToNameMaps();
        Assert.areEqual('Kontakt NAV', maps.get('Tema').get('KNA'));
        Assert.areEqual('Different name', maps.get('Oppgavetyper').get('KNA'));
    }
    */

    private class RepresentationMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        RepresentationMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            if (request.getEndpoint().contains('token')) {
                response.setStatusCode(200);
                response.setBody('{"access_token":"test-token","token_type":"Bearer","expires_in":3600}');
            } else {
                Assert.isFalse(request.getBody().contains('null'), 'Verification must receive both identifiers.');
                response.setStatusCode(statusCode);
                response.setBody(body);
            }
            return response;
        }
    }
}

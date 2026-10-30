@IsTest
private class stoPersonContextTest {
    private class BarnMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        public Integer calls = 0;
        public Integer verificationStatusCode = 200;
        public String verificationBody;

        public BarnMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            calls++;
            Assert.areEqual('POST', request.getMethod());
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Id actorAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
            String actorIdent = [
                SELECT INT_PersonIdent__c
                FROM Account
                WHERE Id = :actorAccountId
            ]
            .INT_PersonIdent__c;
            HttpResponse response = new HttpResponse();
            if (request.getEndpoint().endsWith('/api/foreldreansvar/verifiser')) {
                Assert.areEqual(new Set<String>{ 'forelderIdent', 'barnIdent' }, payload.keySet());
                Assert.areEqual(actorIdent, payload.get('forelderIdent'), 'Never use a hardcoded parent');
                Assert.isTrue(
                    new Set<String>{ '12345678904', '12345678905' }.contains((String) payload.get('barnIdent'))
                );
                response.setStatusCode(verificationStatusCode);
                Set<String> childIdents = stoPersonContext.scratchFamily().get(actorIdent);
                response.setBody(
                    verificationBody != null
                        ? verificationBody
                        : JSON.serialize(
                              new Map<String, Object>{
                                  'kanRepresentere' => childIdents != null &&
                                  childIdents.contains((String) payload.get('barnIdent'))
                              }
                          )
                );
                return response;
            }
            Assert.isTrue(request.getEndpoint().endsWith('/api/foreldreansvar/barn'));
            Assert.areEqual(new Set<String>{ 'ident' }, payload.keySet());
            Assert.areEqual(actorIdent, payload.get('ident'), 'Always use the authenticated parent identity');
            response.setStatusCode(statusCode);
            response.setHeader('Content-Type', 'application/json');
            if (responseBody != null) {
                response.setBody(responseBody);
            } else {
                List<Object> children = new List<Object>();
                Set<String> childIdents = stoPersonContext.scratchFamily().get(actorIdent);
                if (childIdents != null) {
                    for (String ident : childIdents) {
                        children.add(
                            new Map<String, Object>{
                                'ident' => ident,
                                'fornavn' => null,
                                'etternavn' => null,
                                'foedselsdato' => null,
                                'foedselsaar' => null
                            }
                        );
                    }
                }
                response.setBody(JSON.serialize(new Map<String, Object>{ 'barn' => children }));
            }
            return response;
        }
    }

    @TestSetup
    static void setup() {
        // TODO(backend-ready): REPLACE synthetic identity dependencies in integration tests with approved provider fixtures.
        for (
            String ident : new List<String>{ '12345678901', '12345678902', '12345678903', '12345678904', '12345678905' }
        ) {
            STO_TestDataFactory.createRecord(
                new Person__c(
                    Name = ident,
                    INT_FirstName__c = 'Test',
                    INT_LastName__c = 'Family' + ident,
                    INT_Confidential__c = 'UGRADERT',
                    INT_Sex__c = ident == '12345678904' ? 'Kvinne' : 'Mann',
                    INT_DateOfBirth__c = String.valueOf(
                        Date.today().addYears(ident == '12345678904' ? -8 : ident == '12345678905' ? -12 : -35)
                    )
                )
            );
        }
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Kontakt NAV', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Tema')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Sporsmal og Svar', CRM_Code__c = 'SPM_OG_SVR', CRM_Code_Set__c = 'Oppgavetyper')
        );
    }

    private static Account child() {
        return [
            SELECT Id, Name, PersonContactId, INT_PersonIdent__c, CRM_Person__c, CRM_Person__r.INT_DateOfBirth__c
            FROM Account
            WHERE INT_PersonIdent__c = '12345678904'
            LIMIT 1
        ];
    }

    @IsTest
    static void ownershipAndInbox() {
        Account child = child();
        stoPersonContext.testChildren = new List<Account>{ child };
        Assert.areEqual(child.Id, stoPersonContext.getRepresentableChildren()[0].value);
        Assert.areEqual(child.Name + ' (8 år)', stoPersonContext.getRepresentableChildren()[0].label);
        Assert.areEqual(
            child.INT_PersonIdent__c,
            stoPersonContext.getRepresentableChildren()[0].representedPersonIdentifier
        );
        stoHelperClass.ThreadData info = childThreadData(child.Id);
        info.msgText = 'For child';
        Thread__c thread = stoHelperClass.createThread(info);
        Thread__c saved = [SELECT CRM_Account__c, CRM_Contact__c, CreatedById FROM Thread__c WHERE Id = :thread.Id];
        Test.startTest();
        Assert.areEqual(child.Id, saved.CRM_Account__c);
        Assert.areEqual(child.PersonContactId, saved.CRM_Contact__c);
        Assert.areEqual(UserInfo.getUserId(), saved.CreatedById);
        Assert.areEqual(
            [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId,
            [
                SELECT CRM_From_Contact__c
                FROM Message__c
                WHERE CRM_Thread__c = :thread.Id AND CRM_Type__c = 'Message'
                LIMIT 1
            ]
            .CRM_From_Contact__c
        );
        Assert.areEqual(thread.Id, stoInboxHelper.getRecentThreadsForPerson(child.Id)[0].recordId);
        Assert.areEqual(thread.Id, stoHelperClass.getOpenThreadsForPerson('Familie', 'STO', child.Id)[0].recordId);
        Assert.areEqual(0, stoInboxHelper.getRecentThreads().size());
        thread.CRM_Closed_Date__c = Date.today();
        update thread;
        stoThreadReadState.markThreadRead(
            thread.Id,
            [SELECT Id FROM Message__c WHERE CRM_Thread__c = :thread.Id AND CRM_Type__c = 'Message' LIMIT 1].Id
        );
        Assert.areEqual(thread.Id, stoInboxHelper.getThreadsForPerson(child.Id)[0].recordId);
        Test.stopTest();
    }

    @IsTest
    static void dtoIdentifierUsesVerifiedChildAndKeepsParentSender() {
        User parent = createFamilyParents().get('12345678901');
        Test.startTest();
        System.runAs(parent) {
            stoPersonContext.PersonOption selection = stoPersonContext.getRepresentableChildren()[0];
            stoHelperClass.ThreadData info = childThreadData(null);
            info.representedPersonIdentifier = selection.representedPersonIdentifier;
            info = (stoHelperClass.ThreadData) JSON.deserialize(JSON.serialize(info), stoHelperClass.ThreadData.class);
            Thread__c thread = stoHelperClass.createThread(info);
            Account represented = child();
            Assert.areEqual(represented.Id, thread.CRM_Account__c);
            Assert.areEqual(represented.PersonContactId, thread.CRM_Contact__c);
            Assert.areEqual(
                parent.ContactId,
                [SELECT CRM_From_Contact__c FROM Message__c WHERE CRM_Thread__c = :thread.Id LIMIT 1]
                .CRM_From_Contact__c
            );
            Assert.areEqual(thread.Id, stoInboxHelper.getRecentThreadsForPerson(represented.Id)[0].recordId);
        }
        Test.stopTest();
    }

    @IsTest
    static void dtoSelfValidationDoesNotCallForeldreansvar() {
        User parent = createFamilyParents().get('12345678902');
        Test.startTest();
        System.runAs(parent) {
            stoHelperClass.ThreadData info = childThreadData(null);
            Assert.isTrue(info.validateRepresentation());
            Assert.areEqual(0, Limits.getCallouts(), 'Self-sending does not require parental verification');
        }
        Test.stopTest();
    }

    @IsTest
    static void dtoScratchValidationUsesAuthenticatedParent() {
        Map<String, User> parents = createFamilyParents();
        activateMetadataMocks(parents.values());
        Account ola = [SELECT Id, CRM_Person__c FROM Account WHERE INT_PersonIdent__c = '12345678905' LIMIT 1];
        // Account visibility alone must not authorize Anne to represent Ola.
        insert new AccountShare(
            AccountId = ola.Id,
            UserOrGroupId = parents.get('12345678903').Id,
            AccountAccessLevel = 'Read',
            OpportunityAccessLevel = 'None',
            CaseAccessLevel = 'None'
        );
        insert new Person__Share(
            ParentId = ola.CRM_Person__c,
            UserOrGroupId = parents.get('12345678903').Id,
            AccessLevel = 'Read'
        );
        Test.startTest();
        for (String parentIdent : parents.keySet()) {
            System.runAs(parents.get(parentIdent)) {
                for (String childIdent : stoPersonContext.scratchFamily().get(parentIdent)) {
                    stoHelperClass.ThreadData info = childThreadData(null);
                    info.representedPersonIdentifier = childIdent;
                    Assert.isTrue(info.validateRepresentation(), 'Use the authenticated parent and selected child');
                }
                Assert.areEqual(0, Limits.getCallouts(), 'DTO validation must honor the local scratch mock');
            }
        }
        System.runAs(parents.get('12345678903')) {
            stoHelperClass.ThreadData info = childThreadData(null);
            info.representedPersonIdentifier = '12345678905';
            try {
                info.validateRepresentation();
                Assert.fail('Anne must not be allowed to represent Ola');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, Limits.getCallouts());
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void initialSharingSkipsOwnerAndUsesEditForNonOwner() {
        User parent = createFamilyParents().get('12345678901');
        stoPersonContext.testChildren = new List<Account>{ child() };
        Thread__c thread;
        Test.startTest();
        System.runAs(parent) {
            thread = stoHelperClass.createThread(childThreadData(child().Id));
            stoHelperClass.insertFamilieShare(thread);
            Assert.areEqual(
                0,
                [
                    SELECT COUNT()
                    FROM Thread__Share
                    WHERE ParentId = :thread.Id AND UserOrGroupId = :parent.Id AND RowCause = 'Manual'
                ],
                'The owner must not need a redundant manual share'
            );
        }
        stoHelperClass.insertFamilieShare(thread);
        Assert.areEqual(
            'Edit',
            [
                SELECT AccessLevel
                FROM Thread__Share
                WHERE ParentId = :thread.Id AND UserOrGroupId = :UserInfo.getUserId() AND RowCause = 'Manual'
            ]
            .AccessLevel,
            'Salesforce shares use Edit, not Write'
        );
        Test.stopTest();
    }

    @IsTest
    static void verificationDenialPreventsChildThreadAndMessage() {
        assertVerificationDenied(200, '{"kanRepresentere":false}');
    }

    @IsTest
    static void verificationNotFoundPreventsChildThreadAndMessage() {
        assertVerificationDenied(404, '{}');
    }

    @IsTest
    static void verificationNoContentPreventsChildThreadAndMessage() {
        assertVerificationDenied(204, '');
    }

    private static void assertVerificationDenied(Integer statusCode, String body) {
        User parent = createFamilyParents().get('12345678902');
        BarnMock mock = new BarnMock(200, null);
        mock.verificationStatusCode = statusCode;
        mock.verificationBody = body;
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(parent) {
            try {
                stoHelperClass.createThread(childThreadData(child().Id));
                Assert.fail('Verification must deny even when barn and Salesforce sharing allow selection');
            } catch (stoHelperClass.NoParentalResponsibilityException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void malformedVerificationIsAnErrorNotAuthorization() {
        User parent = createFamilyParents().get('12345678902');
        BarnMock mock = new BarnMock(200, null);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(parent) {
            for (String body : new List<String>{ '', 'not json', 'null', '{}', '{"kanRepresentere":null}' }) {
                mock.verificationBody = body;
                try {
                    stoHelperClass.createThread(childThreadData(child().Id));
                    Assert.fail('Malformed verification must not authorize creation');
                } catch (AuraHandledException expected) {
                    Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                    Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
                }
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void verificationServiceFailurePreventsCreation() {
        User parent = createFamilyParents().get('12345678902');
        BarnMock mock = new BarnMock(200, null);
        mock.verificationStatusCode = 500;
        mock.verificationBody = '{"title":"Internal Server Error"}';
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(parent) {
            try {
                stoHelperClass.createThread(childThreadData(child().Id));
                Assert.fail('Verification errors must prevent creation');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void dtoRejectsSharedButUnverifiedChildIdentifier() {
        User parent = createFamilyParents().get('12345678901');
        Test.setMock(HttpCalloutMock.class, new BarnMock(200, '{"barn":[]}'));
        Test.startTest();
        System.runAs(parent) {
            stoHelperClass.ThreadData info = childThreadData(null);
            info.representedPersonIdentifier = '12345678904';
            try {
                stoHelperClass.createThread(info);
                Assert.fail('The incoming DTO must not bypass barn authorization');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void dtoRejectsMissingOrBlankPersonIdentifier() {
        User parent = createFamilyParents().get('12345678901');
        Test.startTest();
        System.runAs(parent) {
            stoHelperClass.ThreadData info = childThreadData(null);
            info.representedPersonIdentifier = '12345678999';
            try {
                stoHelperClass.createThread(info);
                Assert.fail('An unknown identifier must not become a self thread');
            } catch (stoHelperClass.ChildAccountNotFoundException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
            for (String identifier : new List<String>{ '', '   ' }) {
                info.representedPersonIdentifier = identifier;
                try {
                    stoHelperClass.createThread(info);
                    Assert.fail('A blank identifier must not become a self thread');
                } catch (AuraHandledException expected) {
                    Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                    Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
                }
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void rejectsUnrelatedAccounts() {
        stoPersonContext.testChildren = new List<Account>();
        Id childId = child().Id;
        try {
            stoHelperClass.createThread(childThreadData(childId));
            Assert.fail('Unrelated account must be rejected');
        } catch (AuraHandledException expected) {
            Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
        }
        try {
            stoInboxHelper.getRecentThreadsForPerson(childId);
            Assert.fail('Unrelated inbox must be rejected');
        } catch (AuraHandledException expected) {
            Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
        }
    }

    @IsTest
    static void limitsArePersonScoped() {
        User parent = createFamilyParents().get('12345678901');
        Account child = child();
        stoPersonContext.testChildren = new List<Account>{ child };
        Test.startTest();
        System.runAs(parent) {
            stoHelperClass.ThreadData selfInfo = childThreadData(null);
            selfInfo.msgText = 'Self';
            for (Integer i = 0; i < 3; i++) {
                stoHelperClass.createThread(selfInfo);
            }
            stoHelperClass.ThreadData childInfo = childThreadData(child.Id);
            childInfo.msgText = 'Child';
            Thread__c thread = stoHelperClass.createThread(childInfo);
            Assert.areEqual(child.Id, thread.CRM_Account__c);
            for (Integer i = 0; i < 2; i++) {
                stoHelperClass.createThread(childInfo);
            }
            try {
                childInfo.msgText = 'Too many';
                stoHelperClass.createThread(childInfo);
                Assert.fail('The child must have the same three-thread limit');
            } catch (stoHelperClass.maxThreadLimitReachedException expected) {
                Assert.areEqual(3, stoHelperClass.getOpenThreadsForPerson('Familie', 'STO', child.Id).size());
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void childLoginCanReadOwnedThread() {
        // TODO(backend-ready): KEEP this citizen-license end-to-end regression; REPLACE scratch profile/permission/domain setup.
        Account child = child();
        // TODO(backend-ready): Revalidate against the deployed site's existing community profile, not a standard external profile.
        Id communityProfileId = [
            SELECT ProfileId
            FROM User
            WHERE UserType = 'PowerCustomerSuccess' AND IsActive = TRUE AND ContactId != NULL
            LIMIT 1
        ]
        .ProfileId;
        // TODO(backend-ready): Prefer the child profile without fixture opt-in where the scratch setup is installed.
        List<Profile> scratchChildProfiles = [SELECT Id FROM Profile WHERE Name = 'Scratch Community Login Profile'];
        if (!scratchChildProfiles.isEmpty()) {
            communityProfileId = scratchChildProfiles[0].Id;
        }
        User childUser = new User(
            Username = 'child.' + UserInfo.getOrganizationId() + '@ownership.test',
            Email = 'child@example.test',
            LastName = 'Child',
            Alias = 'child',
            CommunityNickname = 'ownershipChild',
            ProfileId = communityProfileId,
            ContactId = child.PersonContactId,
            TimeZoneSidKey = 'Europe/Oslo',
            LocaleSidKey = 'no_NO',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'no'
        );
        Account parent = [SELECT Id, PersonContactId FROM Account WHERE INT_PersonIdent__c = '12345678901' LIMIT 1];
        User parentUser = new User(
            Username = 'parent.' + UserInfo.getOrganizationId() + '@ownership.test',
            Email = 'parent@example.test',
            LastName = 'Parent',
            Alias = 'parent',
            CommunityNickname = 'ownershipParent',
            ProfileId = communityProfileId,
            ContactId = parent.PersonContactId,
            TimeZoneSidKey = 'Europe/Oslo',
            LocaleSidKey = 'no_NO',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'no'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ childUser, parentUser };
            Id experiencePermissionId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Experience' LIMIT 1].Id;
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(AssigneeId = parentUser.Id, PermissionSetId = experiencePermissionId),
                new PermissionSetAssignment(AssigneeId = childUser.Id, PermissionSetId = experiencePermissionId)
            };
            // TODO(backend-ready): Test explicit fixture opt-in without granting it to the child.
            insert new PermissionSetAssignment(
                AssigneeId = parentUser.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Scratch_Family' LIMIT 1]
                .Id
            );
        }
        // TODO(backend-ready): Real authorization must also supply the prerequisite Account/Contact access.
        insert new AccountShare(
            AccountId = child.Id,
            UserOrGroupId = parentUser.Id,
            AccountAccessLevel = 'Edit',
            OpportunityAccessLevel = 'None',
            CaseAccessLevel = 'None',
            RowCause = Schema.AccountShare.RowCause.Manual
        );
        insert new Person__Share(ParentId = child.CRM_Person__c, UserOrGroupId = parentUser.Id, AccessLevel = 'Read');
        Test.setMock(HttpCalloutMock.class, new BarnMock(200, null));
        Test.startTest();
        loadBarnFor(new List<User>{ childUser });
        Thread__c thread;
        System.runAs(parentUser) {
            stoPersonContext.testChildren = null;
            Assert.isTrue(FeatureManagement.checkPermission('STO_Scratch_Family'));
            List<stoPersonContext.PersonOption> actualSelections = stoPersonContext.getRepresentableChildren();
            Assert.areEqual(1, actualSelections.size(), 'Only Beate is shared with this parent');
            Assert.areEqual(child.Id, actualSelections[0].value);
            stoHelperClass.ThreadData info = childThreadData(child.Id);
            info.msgText = 'Child inbox';
            thread = stoHelperClass.createThread(info);
            Assert.areEqual(child.Id, [SELECT CRM_Account__c FROM Thread__c WHERE Id = :thread.Id].CRM_Account__c);
            Assert.areEqual(parentUser.Id, [SELECT CreatedById FROM Thread__c WHERE Id = :thread.Id].CreatedById);
            Assert.areEqual(
                parent.PersonContactId,
                [
                    SELECT CRM_From_Contact__c
                    FROM Message__c
                    WHERE CRM_Thread__c = :thread.Id AND CRM_Type__c = 'Message'
                    LIMIT 1
                ]
                .CRM_From_Contact__c
            );
        }
        System.runAs(childUser) {
            // TODO(backend-ready): Exercise the real selection path under the citizen license, not only injected account selections.
            stoPersonContext.testChildren = null;
            Assert.isFalse(FeatureManagement.checkPermission('STO_Scratch_Family'));
            Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
            Assert.areEqual(thread.Id, stoInboxHelper.getRecentThreads()[0].recordId);
            Assert.areEqual(child.Id, stoPersonContext.resolveAccountId(child.Id));
        }
        Test.stopTest();
    }

    @IsTest
    static void activeThreadCardsUseInboxSenderLabels() {
        Map<String, User> parents = createFamilyParents();
        User childViewer = createChildViewer();
        User starter = parents.get('12345678901');
        User otherParent = parents.get('12345678902');
        Account represented = child();
        String starterName = [SELECT Name FROM Contact WHERE Id = :starter.ContactId].Name;
        Test.startTest();
        loadBarnFor(new List<User>{ starter, otherParent, childViewer });
        Thread__c thread = startThread(starter, represented.Id);
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Info',
            CRM_Message_Text__c = 'Latest message from Nav',
            CRM_Sent_date__c = System.now().addMinutes(1)
        );
        System.runAs(starter) {
            stoInboxHelper.thread card = stoHelperClass.getAccessibleOpenThreadsForPerson(
                'Familie',
                'STO',
                represented.Id
            )[0];
            Assert.areEqual(thread.Id, card.recordId);
            Assert.isNull(card.inboxSenderLabel, 'The starter sees the same card as in the inbox');
        }
        System.runAs(otherParent) {
            stoInboxHelper.thread card = stoHelperClass.getAccessibleOpenThreadsForPerson(
                'Familie',
                'STO',
                represented.Id
            )[0];
            Assert.areEqual(thread.Id, card.recordId);
            Assert.areEqual(starterName + ' startet samtalen', card.inboxSenderLabel);
            Assert.areEqual('Latest message from Nav', card.latestmessage.messageText);
            Assert.areEqual(
                stoInboxHelper.getInboxPage(represented.Id, null, null).recent[0].inboxSenderLabel,
                card.inboxSenderLabel,
                'Use the first message sender, not the latest message sender'
            );
        }
        System.runAs(childViewer) {
            stoInboxHelper.thread card = stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', null)[0];
            Assert.areEqual(starterName + ' startet samtalen', card.inboxSenderLabel);
            Assert.areEqual(card.inboxSenderLabel, stoHelperClass.getOpenThreads('Familie', 'STO')[0].inboxSenderLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void sharedThreadHasIndependentPersistentReceipts() {
        Map<String, User> parents = createFamilyParents();
        User childViewer = createChildViewer();
        Account represented = child();
        User firstReader = parents.get('12345678901');
        User otherReader = parents.get('12345678902');
        String starterName = [SELECT Name FROM Contact WHERE Id = :firstReader.ContactId].Name;
        Test.startTest();
        Thread__c thread = startThread(firstReader, represented.Id);
        update new Thread__c(Id = thread.Id, CRM_Closed_Date__c = Date.today());
        Message__c incoming = new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Info',
            CRM_Message_Text__c = 'Nav message for all readers',
            CRM_Read__c = false
        );
        insert incoming;
        stoPersonContext.testChildren = new List<Account>{ represented };
        System.runAs(otherReader) {
            stoInboxHelper.getAccessibleInboxPage(represented.Id, null, null);
            stoThreadReadState.markThreadRead(thread.Id, incoming.Id);
            Assert.isTrue(
                [SELECT CRM_Read__c FROM Message__c WHERE Id = :incoming.Id].CRM_Read__c,
                'A read-only co-parent must be able to record reading a new counsellor reply'
            );
        }
        System.runAs(firstReader) {
            stoThreadReadState.markThreadRead(thread.Id, incoming.Id);
            stoInboxHelper.InboxPage page = stoInboxHelper.getInboxPage(represented.Id, null, null);
            Assert.areEqual(0, page.recent.size());
            Assert.areEqual(thread.Id, page.older[0].recordId);
            Assert.areEqual(0, page.older[0].numberOfUnreadMessages);
            Assert.isNull(page.older[0].inboxSenderLabel, 'The starter sees no sender text in history');
        }
        System.runAs(childViewer) {
            stoPersonContext.testChildren = null;
            stoInboxHelper.InboxPage page = stoInboxHelper.getInboxPage(null, null, null);
            Assert.areEqual(thread.Id, page.recent[0].recordId);
            Assert.areEqual(starterName + ' startet samtalen', page.recent[0].inboxSenderLabel);
            Assert.areEqual(
                1,
                page.recent[0].numberOfUnreadMessages,
                'Global markAsRead by a parent must not create a receipt for the child'
            );
            stoThreadReadState.markThreadRead(thread.Id, incoming.Id);
            Assert.areEqual(thread.Id, stoInboxHelper.getInboxPage(null, null, null).older[0].recordId);
        }
        stoPersonContext.testChildren = new List<Account>{ represented };
        System.runAs(otherReader) {
            stoInboxHelper.InboxPage page = stoInboxHelper.getInboxPage(represented.Id, null, null);
            Assert.areEqual(0, page.older[0].numberOfUnreadMessages, 'The co-parent has their own receipt');
            Assert.areEqual(starterName + ' startet samtalen', page.older[0].inboxSenderLabel);
            Assert.areEqual(1, [SELECT COUNT() FROM STO_Thread_Read_State__c], 'Only the co-parent receipt is visible');
            stoThreadReadState.markThreadRead(thread.Id, incoming.Id);
        }
        Assert.areEqual(
            3,
            [SELECT COUNT() FROM STO_Thread_Read_State__c WHERE Thread__c = :thread.Id WITH SYSTEM_MODE]
        );
        Test.stopTest();
    }

    @IsTest
    static void ordinaryUserHasNoFixtureChildren() {
        // TODO(backend-ready): KEEP the no-unauthorized-selections assertion; REPLACE fixture-specific expectations if needed.
        Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
        Assert.areEqual(
            [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId,
            stoPersonContext.resolveContactId(null)
        );
    }

    private static Map<String, User> createFamilyParents() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Scratch Community Login Profile' LIMIT 1].Id;
        Set<String> parentIdents = stoPersonContext.scratchFamily().keySet();
        Map<String, User> parents = new Map<String, User>();
        for (Account parent : [
            SELECT PersonContactId, INT_PersonIdent__c
            FROM Account
            WHERE INT_PersonIdent__c IN :parentIdents
        ]) {
            parents.put(
                parent.INT_PersonIdent__c,
                new User(
                    Username = parent.INT_PersonIdent__c + '.' + UserInfo.getOrganizationId() + '@family.test',
                    Email = 'parent@example.test',
                    LastName = 'Parent',
                    Alias = 'parent',
                    CommunityNickname = 'family' + parent.INT_PersonIdent__c,
                    ProfileId = profileId,
                    ContactId = parent.PersonContactId,
                    TimeZoneSidKey = 'Europe/Oslo',
                    LocaleSidKey = 'no_NO',
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'no'
                )
            );
        }
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert parents.values();
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (PermissionSet permission : [
                SELECT Id
                FROM PermissionSet
                WHERE Name IN ('STO_Experience', 'STO_Scratch_Family', 'STO_Thread_Representation_Label')
            ]) {
                for (User parent : parents.values()) {
                    assignments.add(
                        new PermissionSetAssignment(AssigneeId = parent.Id, PermissionSetId = permission.Id)
                    );
                }
            }
            insert assignments;
        }
        Map<String, Account> children = new Map<String, Account>();
        for (Account child : [
            SELECT Id, INT_PersonIdent__c, CRM_Person__c
            FROM Account
            WHERE INT_PersonIdent__c IN ('12345678904', '12345678905')
        ]) {
            children.put(child.INT_PersonIdent__c, child);
        }
        List<AccountShare> shares = new List<AccountShare>();
        List<Person__Share> personShares = new List<Person__Share>();
        for (String parentIdent : parents.keySet()) {
            for (String childIdent : stoPersonContext.scratchFamily().get(parentIdent)) {
                shares.add(
                    new AccountShare(
                        AccountId = children.get(childIdent).Id,
                        UserOrGroupId = parents.get(parentIdent).Id,
                        AccountAccessLevel = 'Edit',
                        OpportunityAccessLevel = 'None',
                        CaseAccessLevel = 'None'
                    )
                );
                personShares.add(
                    new Person__Share(
                        ParentId = children.get(childIdent).CRM_Person__c,
                        UserOrGroupId = parents.get(parentIdent).Id,
                        AccessLevel = 'Read'
                    )
                );
            }
        }
        insert shares;
        insert personShares;
        Test.setMock(HttpCalloutMock.class, new BarnMock(200, null));
        return parents;
    }

    // Separate UI requests authorize before writes; prime each actor before test-only cross-user DML.
    private static void loadBarnFor(List<User> actors) {
        for (User actor : actors) {
            System.runAs(actor) {
                stoPersonContext.getRepresentableChildren();
            }
        }
    }

    @IsTest
    static void doktorCanCreateSharedChildThread() {
        assertParentCanCreateSharedChildThread('12345678901');
    }

    @IsTest
    static void kariCanCreateSharedChildThread() {
        assertParentCanCreateSharedChildThread('12345678902');
    }

    @IsTest
    static void anneCanCreateSharedChildThread() {
        assertParentCanCreateSharedChildThread('12345678903');
    }

    private static void assertParentCanCreateSharedChildThread(String parentIdent) {
        Map<String, User> parents = createFamilyParents();
        Set<Id> createdThreadIds = new Set<Id>();
        Map<Id, Id> creators = new Map<Id, Id>();
        Map<String, Account> children = new Map<String, Account>();
        for (Account child : [
            SELECT Id, PersonContactId, INT_PersonIdent__c
            FROM Account
            WHERE INT_PersonIdent__c IN ('12345678904', '12345678905')
        ]) {
            children.put(child.INT_PersonIdent__c, child);
        }
        Test.startTest();
        loadBarnFor(parents.values());
        System.runAs(parents.get(parentIdent)) {
            Assert.isTrue(FeatureManagement.checkPermission('STO_Scratch_Family'));
            List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
            Set<Id> expected = new Set<Id>();
            for (String childIdent : stoPersonContext.scratchFamily().get(parentIdent)) {
                expected.add(children.get(childIdent).Id);
            }
            Set<Id> actual = new Set<Id>();
            for (stoPersonContext.PersonOption option : options) {
                actual.add(option.value);
            }
            Assert.areEqual(expected, actual, parentIdent);
            Account beate = children.get('12345678904');
            stoHelperClass.ThreadData info = childThreadData(beate.Id);
            info.msgText = 'Foreldreansvar test';
            info.inboxTheme = 'Familie og barn';
            Thread__c created = stoHelperClass.createThread(info);
            Thread__c saved = [
                SELECT CRM_Account__c, CRM_Contact__c, CreatedById
                FROM Thread__c
                WHERE Id = :created.Id
            ];
            createdThreadIds.add(saved.Id);
            creators.put(saved.Id, saved.CreatedById);
            Assert.areEqual(beate.Id, saved.CRM_Account__c);
            Assert.areEqual(beate.PersonContactId, saved.CRM_Contact__c);
            Assert.areEqual(parents.get(parentIdent).Id, saved.CreatedById);
            if (parentIdent == '12345678903') {
                try {
                    stoPersonContext.resolveAccountId(children.get('12345678905').Id);
                    Assert.fail('Medmor must not represent Ola');
                } catch (AuraHandledException expectedError) {
                    Assert.areEqual(1, options.size());
                }
            }
        }
        for (User parent : parents.values()) {
            System.runAs(parent) {
                stoInboxHelper.getAccessibleInboxPage(children.get('12345678904').Id, null, null);
            }
        }
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            Assert.areEqual(
                2,
                [SELECT COUNT() FROM Thread__Share WHERE ParentId IN :createdThreadIds AND AccessLevel = 'Read'],
                'Each verified co-parent receives a Read share when opening Beate inbox'
            );
            for (User parent : parents.values()) {
                System.runAs(parent) {
                    for (UserRecordAccess access : [
                        SELECT RecordId, HasReadAccess, HasEditAccess
                        FROM UserRecordAccess
                        WHERE UserId = :parent.Id AND RecordId IN :createdThreadIds
                    ]) {
                        Assert.isTrue(access.HasReadAccess, 'All three parents can read Beate threads');
                        Assert.areEqual(
                            creators.get(access.RecordId) == parent.Id,
                            access.HasEditAccess,
                            'Only the starter can edit'
                        );
                    }
                }
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void verificationCacheIsScopedToParentAndReusesDenial() {
        Map<String, User> parents = createFamilyParents();
        Id childId = child().Id;
        BarnMock mock = new BarnMock(200, null);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(parents.get('12345678901')) {
            Assert.isTrue(stoPersonContext.verifyRepresentation(childId));
        }
        mock.verificationBody = '{"kanRepresentere":false}';
        System.runAs(parents.get('12345678903')) {
            Assert.isFalse(stoPersonContext.verifyRepresentation(childId));
            Assert.isFalse(stoPersonContext.verifyRepresentation(childId));
        }
        System.runAs(parents.get('12345678901')) {
            Assert.isTrue(stoPersonContext.verifyRepresentation(childId));
        }
        Assert.areEqual(4, mock.calls, 'Each parent needs one barn and one verifiser call, including denials');
        Test.stopTest();
    }

    @IsTest
    static void barnAuthorizesWithoutScratchPermissionAndCachesPerActor() {
        Map<String, User> parents = createFamilyParents();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            delete [
                SELECT Id
                FROM PermissionSetAssignment
                WHERE PermissionSet.Name = 'STO_Scratch_Family' AND AssigneeId IN :parents.values()
            ];
        }
        BarnMock mock = new BarnMock(200, null);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        for (String ident : new List<String>{ '12345678901', '12345678903' }) {
            System.runAs(parents.get(ident)) {
                Assert.isFalse(FeatureManagement.checkPermission('STO_Scratch_Family'));
                List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
                Assert.areEqual(ident == '12345678901' ? 2 : 1, options.size());
                Id childId = child().Id;
                Assert.areEqual(childId, stoPersonContext.resolveAccountId(childId));
                Assert.areEqual(child().PersonContactId, stoPersonContext.resolveContactId(childId));
            }
        }
        Assert.areEqual(2, mock.calls, 'Selection and account/contact validation reuse one barn call per actor');
        Test.stopTest();
    }

    @IsTest
    static void scratchMocksSupplyRepresentableChildrenWithoutCallouts() {
        Map<String, User> parents = createFamilyParents();
        activateMetadataMocks(parents.values());
        Test.startTest();
        for (String parentIdent : parents.keySet()) {
            System.runAs(parents.get(parentIdent)) {
                List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
                Assert.areEqual(parentIdent == '12345678903' ? 1 : 2, options.size());
                Assert.areEqual(child().Id, stoPersonContext.resolveAccountId(child().Id));
                Assert.areEqual(child().PersonContactId, stoPersonContext.resolveContactId(child().Id));
                stoInboxHelper.getInboxPage(child().Id, null, null);
                Assert.areEqual(0, Limits.getCallouts(), 'The local scratch fixture must not call PDL');
            }
        }
        System.runAs(parents.get('12345678902')) {
            Thread__c thread = stoHelperClass.createThread(childThreadData(child().Id));
            Assert.areEqual(child().Id, thread.CRM_Account__c);
            Assert.areEqual(0, Limits.getCallouts(), 'Both barn and verifiser must use local scratch mocks');
        }
        Test.stopTest();
    }

    @IsTest
    static void scratchOlaHasNoRepresentationOptionsButCanWriteForSelf() {
        Account ola = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE INT_PersonIdent__c = '12345678905'
        ];
        assertScratchChildSelfService(ola);
    }

    @IsTest
    static void scratchBeateHasNoRepresentationOptionsButCanWriteForSelf() {
        assertScratchChildSelfService(child());
    }

    private static void assertScratchChildSelfService(Account account) {
        User childUser = createChildViewer(account);
        User actor = [
            SELECT AccountId, Account.CRM_Person__r.INT_DateOfBirth__c
            FROM User
            WHERE Id = :childUser.Id
        ];
        Assert.areEqual(account.Id, actor.AccountId, 'The child login must belong to the child account');
        Assert.isNotNull(actor.Account.CRM_Person__r.INT_DateOfBirth__c, 'The child must have a known birth date');
        Assert.isTrue(
            Date.valueOf(actor.Account.CRM_Person__r.INT_DateOfBirth__c).addYears(18) > Date.today(),
            'The actor must be younger than 18'
        );
        BarnMock failure = new BarnMock(500, '{"title":"Internal Server Error"}');
        Test.setMock(HttpCalloutMock.class, failure);
        Test.startTest();
        System.runAs(childUser) {
            Assert.isFalse(stoForeldreansvarMock.isEnabled(), 'Child eligibility must not depend on scratch mocks');
            Assert.isFalse(FeatureManagement.checkPermission('STO_Scratch_Family'));
            Assert.areEqual(
                0,
                stoPersonContext.getRepresentableChildren().size(),
                'No children is not a loading error'
            );
            Assert.areEqual(account.Id, stoPersonContext.resolveAccountId(null));
            Assert.areEqual(account.PersonContactId, stoPersonContext.resolveContactId(account.Id));
            for (String type : new List<String>{ 'STO', 'BTO' }) {
                stoHelperClass.ThreadData info = childThreadData(null);
                info.type = type;
                Thread__c thread = stoHelperClass.createThread(info);
                Assert.areEqual(account.Id, thread.CRM_Account__c);
                Assert.areEqual(account.PersonContactId, thread.CRM_Contact__c);
            }
            Assert.areEqual(0, Limits.getCallouts(), 'Child self-service must not reach the live responsibility API');
            Assert.areEqual(0, failure.calls);
        }
        Test.stopTest();
    }

    @IsTest
    static void representationLookupStartsOnEighteenthBirthday() {
        Person__c person = [SELECT Id FROM Person__c WHERE Name = '12345678905'];
        person.INT_DateOfBirth__c = String.valueOf(Date.today().addYears(-18));
        update person;
        Account ola = [SELECT Id, PersonContactId FROM Account WHERE INT_PersonIdent__c = '12345678905'];
        User actor = createChildViewer(ola);
        BarnMock mock = new BarnMock(200, '{"barn":[]}');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(actor) {
            Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
            Assert.areEqual(1, mock.calls, 'An adult must still use the responsibility service');
        }
        Test.stopTest();
    }

    @IsTest
    static void representationLookupSkipsDayBeforeEighteenthBirthday() {
        Person__c person = [SELECT Id FROM Person__c WHERE Name = '12345678905'];
        person.INT_DateOfBirth__c = String.valueOf(Date.today().addYears(-18).addDays(1));
        update person;
        Account ola = [SELECT Id, PersonContactId FROM Account WHERE INT_PersonIdent__c = '12345678905'];
        assertScratchChildSelfService(ola);
    }

    @IsTest
    static void missingActorBirthDateDoesNotHideServiceFailure() {
        Map<String, User> parents = createFamilyParents();
        Person__c person = [SELECT Id FROM Person__c WHERE Name = '12345678901'];
        person.INT_DateOfBirth__c = null;
        update person;
        Test.setMock(HttpCalloutMock.class, new BarnMock(500, '{"title":"Internal Server Error"}'));
        Test.startTest();
        System.runAs(parents.get('12345678901')) {
            try {
                stoPersonContext.getRepresentableChildren();
                Assert.fail('Missing birth date must not be interpreted as a known child');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.isTrue(expected.getMessage().contains('LoggId'));
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void scratchVerificationMatchesParentAndChild() {
        Map<String, User> parents = createFamilyParents();
        activateMetadataMocks(parents.values());
        Test.startTest();
        for (String parentIdent : parents.keySet()) {
            System.runAs(parents.get(parentIdent)) {
                for (String childIdent : new List<String>{ '12345678904', '12345678905', '12345678999' }) {
                    HttpResponse response = stoForeldreansvarMock.verifiser(parentIdent, childIdent);
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Assert.areEqual(200, response.getStatusCode());
                    Assert.areEqual(
                        stoPersonContext.scratchFamily().get(parentIdent).contains(childIdent),
                        body.get('kanRepresentere'),
                        'Only the configured parent-child pairs may be represented'
                    );
                }
                for (String nonParentIdent : new List<String>{ '12345678904', '12345678999' }) {
                    HttpResponse response = stoForeldreansvarMock.verifiser(nonParentIdent, '12345678904');
                    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Assert.areEqual(false, body.get('kanRepresentere'), 'Unknown parents must not be authorized');
                }
                Assert.areEqual(0, Limits.getCallouts(), 'Pair matching must stay inside the configured mock');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void scratchFixtureMatchesDummyFamily() {
        Map<String, Set<String>> family = stoPersonContext.scratchFamily();
        Assert.areEqual(3, family.size());
        Assert.areEqual(new Set<String>{ '12345678904', '12345678905' }, family.get('12345678901'));
        Assert.areEqual(new Set<String>{ '12345678904', '12345678905' }, family.get('12345678902'));
        Assert.areEqual(new Set<String>{ '12345678904' }, family.get('12345678903'));
    }

    @IsTest
    static void localScratchMockRequiresExplicitOptIn() {
        User parent = createFamilyParents().get('12345678901');
        Test.setMock(HttpCalloutMock.class, new BarnMock(200, '{"barn":[]}'));
        Test.startTest();
        System.runAs(parent) {
            Assert.isFalse(stoForeldreansvarMock.isEnabled());
            Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size(), 'Use the API, not local fixtures');
            try {
                stoForeldreansvarMock.verifiser('12345678901', '12345678904');
                Assert.fail('A local fixture response must require explicit opt-in');
            } catch (stoForeldreansvarMock.MockDisabledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void localScratchMockPreservesConfiguredFailures() {
        User parent = createFamilyParents().get('12345678901');
        activateMetadataMocks(new List<User>{ parent });
        System.runAs(new User(Id = UserInfo.getUserId())) {
            API_Controller_Mock_Settings__c setting = API_Controller_Mock_Settings__c.getValues(parent.Id);
            setting.Status_Code__c = '500';
            update setting;
        }
        Test.startTest();
        System.runAs(parent) {
            Assert.isFalse(stoForeldreansvarMock.isEnabled(), 'A failure status must not become a successful fixture');
            try {
                stoPersonContext.getRepresentableChildren();
                Assert.fail('The configured integration error must be preserved');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                Assert.areEqual(0, Limits.getCallouts(), 'The existing ApiController error mock remains active');
            }
        }
        Test.stopTest();
    }

    private static void activateMetadataMocks(List<User> parents) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<API_Controller_Mock_Settings__c> settings = new List<API_Controller_Mock_Settings__c>();
            for (User parent : parents) {
                settings.add(
                    new API_Controller_Mock_Settings__c(
                        SetupOwnerId = parent.Id,
                        Use_Mock__c = true,
                        Status_Code__c = '200',
                        Status__c = 'OK'
                    )
                );
            }
            insert settings;
        }
    }

    @IsTest
    static void barnEmptyListDeniesExistingSharedChild() {
        assertNoBarnChildren(200, '{"barn":[]}');
    }

    @IsTest
    static void barnParentNotFoundDeniesExistingSharedChild() {
        assertNoBarnChildren(404, '{"title":"Not Found"}');
    }

    @IsTest
    static void barnNoContentDeniesExistingSharedChild() {
        assertNoBarnChildren(204, '');
    }

    @IsTest
    static void barnUnknownChildDoesNotCreateAnAccount() {
        assertNoBarnChildren(200, '{"barn":[{"ident":"12345678999"}]}');
    }

    private static void assertNoBarnChildren(Integer statusCode, String responseBody) {
        User parent = createFamilyParents().get('12345678901');
        Id childId = child().Id;
        Test.setMock(HttpCalloutMock.class, new BarnMock(statusCode, responseBody));
        Test.startTest();
        System.runAs(parent) {
            Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
            try {
                stoInboxHelper.getInboxPage(childId, null, null);
                Assert.fail('Sharing alone must not authorize a child inbox');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
            try {
                stoHelperClass.createThread(childThreadData(childId));
                Assert.fail('Sharing alone must not authorize thread registration');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
            try {
                stoPersonContext.resolveContactId(childId);
                Assert.fail('Sharing alone must not authorize the child contact');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
            }
            Assert.areEqual(
                [SELECT AccountId FROM User WHERE Id = :parent.Id].AccountId,
                stoPersonContext.resolveAccountId(null)
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void barnMalformedResponseIsNotAnEmptySuccess() {
        User parent = createFamilyParents().get('12345678901');
        Test.startTest();
        System.runAs(parent) {
            for (
                String body : new List<String>{
                    '',
                    'not json',
                    'null',
                    '{}',
                    '{"barn":null}',
                    '{"barn":[{}]}',
                    '{"barn":[null]}',
                    '{"barn":[{"ident":" "}]}'
                }
            ) {
                Test.setMock(HttpCalloutMock.class, new BarnMock(200, body));
                try {
                    stoPersonContext.getRepresentableChildren();
                    Assert.fail('Invalid barn response must surface an error');
                } catch (AuraHandledException expected) {
                    Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                }
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void barnServiceFailureBlocksRepresentationButNotSelf() {
        User parent = createFamilyParents().get('12345678901');
        Test.setMock(HttpCalloutMock.class, new BarnMock(500, '{"title":"Internal Server Error"}'));
        Test.startTest();
        System.runAs(parent) {
            try {
                stoPersonContext.getRepresentableChildren();
                Assert.fail('Service failure must not look like no children');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.isTrue(expected.getMessage().contains('LoggId'));
            }
            try {
                stoHelperClass.createThread(childThreadData(child().Id));
                Assert.fail('Service failure must block child thread registration');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
            }
            Assert.areEqual(
                [SELECT AccountId FROM User WHERE Id = :parent.Id].AccountId,
                stoPersonContext.resolveAccountId(null)
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void barnDoesNotBypassAccountSharing() {
        User parent = createFamilyParents().get('12345678903');
        Test.setMock(
            HttpCalloutMock.class,
            new BarnMock(200, '{"barn":[{"ident":"12345678904"},{"ident":"12345678905"}]}')
        );
        Test.startTest();
        System.runAs(parent) {
            List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
            Assert.areEqual(1, options.size(), 'Only Beate has been shared with this parent');
            Assert.areEqual(child().Id, options[0].value);
        }
        Test.stopTest();
    }

    @IsTest
    static void protectedAndAdultChildrenAreNotRepresentable() {
        Map<String, User> parents = createFamilyParents();
        Person__c beate = [SELECT Id FROM Person__c WHERE Name = '12345678904'];
        Test.startTest();
        loadBarnFor(new List<User>{ parents.get('12345678903') });
        for (String confidentiality : new List<String>{ 'FORTROLIG', 'STRENGT_FORTROLIG', 'UGRADERT' }) {
            beate.INT_Confidential__c = confidentiality;
            beate.INT_DateOfBirth__c = String.valueOf(
                confidentiality == 'UGRADERT' ? Date.today().addYears(-18) : Date.today().addYears(-8)
            );
            update beate;
            System.runAs(parents.get('12345678903')) {
                Assert.areEqual(0, stoPersonContext.getRepresentableChildren().size());
            }
        }
        Test.stopTest();
    }

    private static User createChildViewer() {
        return createChildViewer(child());
    }

    private static User createChildViewer(Account owner) {
        User viewer = new User(
            Username = 'starter.child.' + UserInfo.getOrganizationId() + '@family.test',
            Email = 'child@example.test',
            LastName = 'Child',
            Alias = 'child',
            CommunityNickname = 'starterChild',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Scratch Community Login Profile' LIMIT 1]
            .Id,
            ContactId = owner.PersonContactId,
            TimeZoneSidKey = 'Europe/Oslo',
            LocaleSidKey = 'no_NO',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'no'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert viewer;
            insert new PermissionSetAssignment(
                AssigneeId = viewer.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Experience' LIMIT 1]
                .Id
            );
            insert new PermissionSetAssignment(
                AssigneeId = viewer.Id,
                PermissionSetId = [
                    SELECT Id
                    FROM PermissionSet
                    WHERE Name = 'STO_Thread_Representation_Label'
                    LIMIT 1
                ]
                .Id
            );
        }
        return viewer;
    }

    private static stoHelperClass.ThreadData childThreadData(Id representedAccountId) {
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.theme = 'Familie';
        info.msgText = 'Original message';
        info.medskriv = true;
        info.type = 'STO';
        info.inboxTitle = 'Skriv til oss';
        info.inboxTheme = 'Familie';
        info.disabilityCampaign = false;
        if (representedAccountId != null) {
            info.representedPersonIdentifier = [
                SELECT INT_PersonIdent__c
                FROM Account
                WHERE Id = :representedAccountId
            ]
            .INT_PersonIdent__c;
        }
        return info;
    }

    private static Thread__c startThread(User starter, Id representedAccountId) {
        Thread__c thread;
        System.runAs(starter) {
            thread = stoHelperClass.createThread(childThreadData(representedAccountId));
        }
        return thread;
    }

    private static void assertCannotMutate(User viewer, Id threadId) {
        System.runAs(viewer) {
            Assert.isFalse(stoHelperClass.getReplyContext(threadId).canReply);
            Integer beforeCount = [SELECT COUNT() FROM Message__c WHERE CRM_Thread__c = :threadId];
            try {
                CRM_MessageHelperExperience.createThreadMessage(threadId, 'Not the original sender');
                Assert.fail('Non-starter must not send through the existing message endpoint');
            } catch (AuraHandledException expected) {
                Assert.areEqual(beforeCount, [SELECT COUNT() FROM Message__c WHERE CRM_Thread__c = :threadId]);
            }
            try {
                stoHelperClass.closeThread(threadId);
                Assert.fail('Non-starter must not close through the existing close endpoint');
            } catch (AuraHandledException expected) {
                Assert.isTrue([SELECT CRM_isActive__c FROM Thread__c WHERE Id = :threadId].CRM_isActive__c);
            }
            Message__c directMessage = new Message__c(
                CRM_Thread__c = threadId,
                CRM_Message_Text__c = 'Direct write attempt',
                CRM_From_Contact__c = viewer.ContactId
            );
            Database.SaveResult messageResult = Database.insert(directMessage, false, AccessLevel.SYSTEM_MODE);
            Assert.isFalse(messageResult.isSuccess(), 'Direct message DML must enforce the same rule');
            Assert.isTrue(
                messageResult.getErrors()[0].getMessage().contains(stoThreadAccess.READ_ONLY_MESSAGE),
                messageResult.getErrors()[0].getMessage()
            );
            Database.SaveResult closeResult = Database.update(
                new Thread__c(Id = threadId, CRM_Closed_Date__c = Date.today()),
                false,
                AccessLevel.SYSTEM_MODE
            );
            Assert.isFalse(closeResult.isSuccess(), 'Direct closure DML must enforce the same rule');
            // Opening the transcript must retain the existing shared backend read marking.
            CRM_MessageHelperExperience.markAsRead(threadId);
        }
    }

    @IsTest
    static void childAndOtherParentCannotReplyOrCloseParentThread() {
        Map<String, User> parents = createFamilyParents();
        User childViewer = createChildViewer();
        Test.startTest();
        loadBarnFor(parents.values());
        Thread__c thread = startThread(parents.get('12345678902'), child().Id);
        for (User parent : parents.values()) {
            System.runAs(parent) {
                stoThreadSharing.prepareInboxAccess(child().Id);
            }
        }
        List<Thread__Share> legacyShares = [
            SELECT Id, AccessLevel
            FROM Thread__Share
            WHERE ParentId = :thread.Id AND RowCause = 'Manual'
        ];
        for (Thread__Share legacyShare : legacyShares) {
            legacyShare.AccessLevel = 'Edit';
        }
        update legacyShares;
        assertCannotMutate(childViewer, thread.Id);
        assertCannotMutate(parents.get('12345678901'), thread.Id);
        String starterName = [SELECT Name FROM Contact WHERE Id = :parents.get('12345678902').ContactId].Name;
        System.runAs(childViewer) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.isNull(context.representedLabel, 'The child must not see a banner representing themselves');
            Assert.areEqual(starterName + ' startet samtalen', context.inboxSenderLabel);
        }
        System.runAs(parents.get('12345678901')) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.areEqual(starterName + ' på vegne av ' + child().Name, context.representedLabel);
            Assert.areEqual(starterName + ' startet samtalen', context.inboxSenderLabel);
            Assert.isFalse(context.canReply);
        }
        System.runAs(parents.get('12345678903')) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.areEqual(starterName + ' på vegne av ' + child().Name, context.representedLabel);
            Assert.areEqual(starterName + ' startet samtalen', context.inboxSenderLabel);
        }
        update new Thread__c(Id = thread.Id, CRM_Closed_Date__c = Date.today());
        System.runAs(childViewer) {
            Assert.isNull(
                stoHelperClass.getReplyContext(thread.Id).representedLabel,
                'Closed parent-started conversations must also hide the banner for the child'
            );
        }
        System.runAs(parents.get('12345678901')) {
            Assert.areEqual(
                starterName + ' på vegne av ' + child().Name,
                stoHelperClass.getReplyContext(thread.Id).representedLabel,
                'The original sender must still be identified after closure'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void verifiedParentReceivesWholeChildInboxReadAccess() {
        Map<String, User> parents = createFamilyParents();
        Account beate = child();
        stoHelperClass.ThreadData info = childThreadData(beate.Id);
        Thread__c first = info.toThread();
        Thread__c second = info.toThread();
        insert new List<Thread__c>{ first, second };
        insert new List<Message__c>{
            new Message__c(
                CRM_Thread__c = first.Id,
                CRM_From_Contact__c = parents.get('12345678901').ContactId,
                CRM_Message_Text__c = 'First parent conversation'
            ),
            new Message__c(
                CRM_Thread__c = second.Id,
                CRM_From_Contact__c = parents.get('12345678902').ContactId,
                CRM_Message_Text__c = 'Other parent conversation'
            )
        };
        update new Thread__c(Id = second.Id, CRM_Closed_Date__c = Date.today());
        Conversation_Note__c note = new Conversation_Note__c(
            CRM_Account__c = beate.Id,
            CRM_Created_By_Ident__c = 'Z999999',
            CRM_Conversation_Note__c = 'Conversation note concerning Beate',
            CRM_Is_Read__c = false
        );
        insert note;
        Conversation_Note__c unpublished = new Conversation_Note__c(
            CRM_Account__c = beate.Id,
            CRM_Conversation_Note__c = 'Unpublished internal note'
        );
        insert unpublished;
        User anne = parents.get('12345678903');
        Test.startTest();
        System.runAs(anne) {
            stoInboxHelper.InboxPage page = stoInboxHelper.getAccessibleInboxPage(beate.Id, null, null);
            Set<Id> records = new Set<Id>();
            for (stoInboxHelper.thread item : page.recent) {
                records.add(item.recordId);
            }
            for (stoInboxHelper.thread item : page.older) {
                records.add(item.recordId);
            }
            Assert.areEqual(new Set<Id>{ first.Id, second.Id, note.Id }, records);
            Assert.areEqual(2, [SELECT COUNT() FROM Thread__c WHERE CRM_Account__c = :beate.Id]);
            Assert.areEqual(0, [SELECT COUNT() FROM Conversation_Note__c WHERE Id = :unpublished.Id]);
            Assert.areEqual(
                'Read',
                [
                    SELECT AccessLevel
                    FROM Conversation_Note__Share
                    WHERE ParentId = :note.Id AND UserOrGroupId = :anne.Id AND RowCause = 'STO_Family_Read__c'
                ]
                .AccessLevel
            );
            Assert.isFalse(stoHelperClass.getReplyContext(first.Id).canReply);
            Assert.isFalse(stoHelperClass.getReplyContext(second.Id).canReply);
            Integer beforeCount = [SELECT COUNT() FROM Thread__Share WHERE UserOrGroupId = :anne.Id];
            stoInboxHelper.getAccessibleInboxPage(beate.Id, null, null);
            Assert.areEqual(beforeCount, [SELECT COUNT() FROM Thread__Share WHERE UserOrGroupId = :anne.Id]);
            Assert.areEqual(
                1,
                [SELECT COUNT() FROM Conversation_Note__Share WHERE ParentId = :note.Id AND UserOrGroupId = :anne.Id]
            );
            stoInboxHelper.markAsRead(note.Id);
            Assert.isTrue([SELECT CRM_Is_Read__c FROM Conversation_Note__c WHERE Id = :note.Id].CRM_Is_Read__c);
        }
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Conversation_Note__Share WHERE ParentId = :unpublished.Id AND UserOrGroupId = :anne.Id]
        );
        Test.stopTest();
    }

    @IsTest
    static void unrelatedParentCannotShareThreadsOrConversationNotes() {
        Map<String, User> parents = createFamilyParents();
        Account ola = [SELECT Id FROM Account WHERE INT_PersonIdent__c = '12345678905'];
        Test.startTest();
        loadBarnFor(parents.values());
        Thread__c thread = startThread(parents.get('12345678901'), ola.Id);
        Conversation_Note__c note = new Conversation_Note__c(
            CRM_Account__c = ola.Id,
            CRM_Created_By_Ident__c = 'Z999999',
            CRM_Conversation_Note__c = 'Conversation note concerning Ola'
        );
        insert note;
        User anne = parents.get('12345678903');
        System.runAs(anne) {
            try {
                stoInboxHelper.getAccessibleInboxPage(ola.Id, null, null);
                Assert.fail('Anne must not receive shares for Ola');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c WHERE Id = :thread.Id]);
                Assert.areEqual(0, [SELECT COUNT() FROM Conversation_Note__c WHERE Id = :note.Id]);
            }
            try {
                stoInboxHelper.markAsRead(note.Id);
                Assert.fail('Anne must not change read flags on an inaccessible note');
            } catch (AuraHandledException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Conversation_Note__c WHERE Id = :note.Id]);
            }
        }
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Thread__Share WHERE ParentId = :thread.Id AND UserOrGroupId = :anne.Id]
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Conversation_Note__Share WHERE ParentId = :note.Id AND UserOrGroupId = :anne.Id]
        );
        Test.stopTest();
    }

    @IsTest
    static void childStoCaseBelongsOnlyToChild() {
        assertCaseUsesThreadSubject('STO', true);
    }

    @IsTest
    static void childBtoCaseBelongsOnlyToChild() {
        assertCaseUsesThreadSubject('BTO', true);
    }

    @IsTest
    static void selfStoCaseKeepsOwnAccountAndContact() {
        assertCaseUsesThreadSubject('STO', false);
    }

    @IsTest
    static void selfBtoCaseKeepsOwnAccountAndContact() {
        assertCaseUsesThreadSubject('BTO', false);
    }

    private static void assertCaseUsesThreadSubject(String threadType, Boolean forChild) {
        User anne = createFamilyParents().get('12345678903');
        Account subject = forChild
            ? child()
            : [SELECT Id, PersonContactId FROM Account WHERE PersonContactId = :anne.ContactId];
        Id threadId;
        Test.startTest();
        System.runAs(anne) {
            stoHelperClass.ThreadData info = childThreadData(forChild ? subject.Id : null);
            info.type = threadType;
            Thread__c thread = info.toThread();
            // Invoke the routing flow synchronously without also scheduling its after-insert path.
            thread.CRM_Thread_Type__c = null;
            insert as system thread;
            thread.CRM_Thread_Type__c = threadType;
            update as system thread;
            threadId = thread.Id;
            thread = [
                SELECT
                    Id,
                    CRM_Account__c,
                    CRM_Contact__c,
                    CRM_Thread_Type__c,
                    STO_Category__c,
                    STO_ExternalName__c,
                    CRM_API_Reference__c,
                    CRM_Account__r.CRM_Person__r.INT_Confidential__c,
                    CRM_Account__r.CRM_Person__r.INT_IsNavEmployee__c
                FROM Thread__c
                WHERE Id = :thread.Id
                WITH SYSTEM_MODE
            ];
            Flow.Interview routing = Flow.Interview.createInterview(
                'STO_Thread_CreateTaskOrCase',
                new Map<String, Object>{ 'Thread' => thread }
            );
            routing.start();
        }
        Test.stopTest();
        Thread__c saved = [SELECT CRM_Case__c FROM Thread__c WHERE Id = :threadId];
        Assert.isNotNull(saved.CRM_Case__c, 'Routing must create and link a case');
        Case created = [SELECT AccountId, ContactId, Origin FROM Case WHERE Id = :saved.CRM_Case__c];
        Assert.areEqual(subject.Id, created.AccountId, 'The case belongs to the thread subject account');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Application_Log__c WHERE Source_Class__c = 'Thread - Subflow - Create STO Case'],
            JSON.serialize(
                [
                    SELECT Log_Message__c
                    FROM Application_Log__c
                    WHERE Source_Class__c = 'Thread - Subflow - Create STO Case'
                ]
            )
        );
        Assert.areEqual(
            subject.PersonContactId,
            created.ContactId,
            'The case contact must be the subject, not the sender'
        );
        Assert.areEqual(threadType, created.Origin);
        Assert.areEqual(1, [SELECT COUNT() FROM Case], 'A submission must create exactly one case');
        if (forChild) {
            Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE ContactId = :anne.ContactId]);
        }
    }

    @IsTest
    static void anneCanReplyAfterCreatingFamilyThreadForBeate() {
        User anne = createFamilyParents().get('12345678903');
        Account beate = child();
        Test.startTest();
        System.runAs(anne) {
            stoHelperClass.ThreadData info = childThreadData(beate.Id);
            info.msgText = 'Message for Beate from Anne';
            info = (stoHelperClass.ThreadData) JSON.deserialize(JSON.serialize(info), stoHelperClass.ThreadData.class);
            Thread__c thread = stoHelperClass.createThread(info);
            Assert.areEqual(beate.Id, thread.CRM_Account__c);
            Assert.areEqual(beate.PersonContactId, thread.CRM_Contact__c);
            Message__c firstMessage = [
                SELECT CRM_From_Contact__c
                FROM Message__c
                WHERE CRM_Thread__c = :thread.Id AND CRM_Type__c = 'Message'
                LIMIT 1
            ];
            Assert.areEqual(anne.ContactId, firstMessage.CRM_From_Contact__c, 'Anne is the sender, not Beate');
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.isTrue(context.canReply, 'The creator must be able to reply immediately after sending');
            Assert.isNull(context.inboxSenderLabel);
            Assert.areEqual('Gjelder: ' + beate.Name + ' (8 år)', context.representedLabel);
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Follow-up from Anne'));
            Assert.areEqual(
                2,
                [
                    SELECT COUNT()
                    FROM Message__c
                    WHERE CRM_Thread__c = :thread.Id AND CRM_From_Contact__c = :anne.ContactId
                ]
            );
            stoHelperClass.closeThread(thread.Id);
            Assert.isFalse([SELECT CRM_isActive__c FROM Thread__c WHERE Id = :thread.Id].CRM_isActive__c);
        }
        Test.stopTest();
    }

    @IsTest
    static void originalParentCanReplyAndClose() {
        User parent = createFamilyParents().get('12345678902');
        Test.startTest();
        Thread__c thread = startThread(parent, child().Id);
        System.runAs(parent) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.isTrue(context.canReply);
            Assert.isNotNull(context.senderName);
            Assert.isNotNull(context.representedName);
            Assert.areEqual('Gjelder: ' + child().Name + ' (8 år)', context.representedLabel);
            Assert.isNull(context.inboxSenderLabel, 'The starter must have no inbox sender text');
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Original parent reply'));
            stoHelperClass.closeThread(thread.Id);
            Assert.isFalse([SELECT CRM_isActive__c FROM Thread__c WHERE Id = :thread.Id].CRM_isActive__c);
            Assert.isNull(stoHelperClass.getReplyContext(thread.Id).inboxSenderLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void childStarterCanReplyButParentCannot() {
        Map<String, User> parents = createFamilyParents();
        User parent = parents.get('12345678901');
        User childViewer = createChildViewer();
        Test.startTest();
        loadBarnFor(parents.values());
        Thread__c thread = startThread(childViewer, null);
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            System.runAs(parent) {
                Assert.areEqual(
                    thread.Id,
                    stoInboxHelper.getAccessibleInboxPage(child().Id, null, null).recent[0].recordId
                );
                Assert.areEqual(
                    'Read',
                    [
                        SELECT AccessLevel
                        FROM Thread__Share
                        WHERE ParentId = :thread.Id AND UserOrGroupId = :parent.Id AND RowCause = 'STO_Family_Read__c'
                    ]
                    .AccessLevel
                );
            }
        } else {
            insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = parent.Id, AccessLevel = 'Read');
        }
        assertCannotMutate(parent, thread.Id);
        System.runAs(parent) {
            Assert.areEqual(
                child().Name + ' startet samtalen',
                stoHelperClass.getReplyContext(thread.Id).inboxSenderLabel
            );
        }
        System.runAs(childViewer) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.isTrue(context.canReply);
            Assert.isNull(context.senderName, 'A self-started thread must not display a representation banner');
            Assert.isNull(context.representedLabel, 'A self-started thread must not display a representation label');
            Assert.isNull(context.inboxSenderLabel, 'The child sees their own self-started inbox item as normal');
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Child starter reply'));
            stoHelperClass.closeThread(thread.Id);
        }
        Test.stopTest();
    }

    @IsTest
    static void childStartedBtoSharesOnlyWithResponsibleParents() {
        Map<String, User> parents = createFamilyParents();
        Account son = [SELECT Id, PersonContactId, CRM_Person__c FROM Account WHERE INT_PersonIdent__c = '12345678905'];
        User childViewer = createChildViewer(son);
        Thread__c thread;
        Test.startTest();
        loadBarnFor(parents.values());
        System.runAs(childViewer) {
            Assert.isFalse(
                FeatureManagement.checkPermission('STO_Scratch_Family'),
                'Children need no parent permission'
            );
            stoHelperClass.ThreadData info = childThreadData(null);
            info.msgText = 'Child BTO';
            info.type = 'BTO';
            info.inboxTitle = 'Meld fra om endring';
            thread = stoHelperClass.createThread(info);
            Assert.isTrue(stoHelperClass.getReplyContext(thread.Id).canReply);
        }
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            for (String ident : new List<String>{ '12345678901', '12345678902' }) {
                System.runAs(parents.get(ident)) {
                    Assert.areEqual(
                        thread.Id,
                        stoInboxHelper.getAccessibleInboxPage(son.Id, null, null).recent[0].recordId
                    );
                }
                assertCannotMutate(parents.get(ident), thread.Id);
            }
            Id medmorId = parents.get('12345678903').Id;
            Assert.areEqual(
                0,
                [SELECT COUNT() FROM Thread__Share WHERE ParentId = :thread.Id AND UserOrGroupId = :medmorId]
            );
            System.runAs(parents.get('12345678903')) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c WHERE Id = :thread.Id]);
            }
        }
        System.runAs(childViewer) {
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Child reply'));
        }
        Test.stopTest();
    }

    @IsTest
    static void protectedOrAdultChildSelfThreadsDoNotGrantFamilyShares() {
        createFamilyParents();
        User childViewer = createChildViewer();
        Person__c person = [
            SELECT Id, INT_Confidential__c, INT_DateOfBirth__c
            FROM Person__c
            WHERE Name = '12345678904'
        ];
        Test.startTest();
        for (String protection : new List<String>{ 'FORTROLIG', 'STRENGT_FORTROLIG', 'UGRADERT' }) {
            person.INT_Confidential__c = protection;
            if (protection == 'UGRADERT') {
                person.INT_DateOfBirth__c = String.valueOf(Date.today().addYears(-18));
            }
            update person;
            Thread__c thread = startThread(childViewer, null);
            Assert.areEqual(0, [SELECT COUNT() FROM Thread__Share WHERE ParentId = :thread.Id AND RowCause = 'Manual']);
        }
        Test.stopTest();
    }

    @IsTest
    static void representedLabelUsesPersonNameAndAgeWithoutRelationship() {
        User parent = createFamilyParents().get('12345678901');
        Account son = [
            SELECT Id, Name
            FROM Account
            WHERE INT_PersonIdent__c = '12345678905'
            LIMIT 1
        ];
        Test.startTest();
        Thread__c thread = startThread(parent, son.Id);
        System.runAs(parent) {
            stoThreadAccess.ReplyContext context = stoHelperClass.getReplyContext(thread.Id);
            Assert.areEqual('Gjelder: ' + son.Name + ' (12 år)', context.representedLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void legacySelfThreadAndInternalAgentKeepAccess() {
        User childViewer = createChildViewer();
        Account owner = child();
        stoHelperClass.ThreadData info = childThreadData(null);
        info.cachedAccountId = owner.Id;
        info.cachedContactId = owner.PersonContactId;
        Thread__c thread = info.toThread();
        insert thread;
        insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = childViewer.Id, AccessLevel = 'Edit');
        Test.startTest();
        System.runAs(childViewer) {
            Assert.isTrue(stoHelperClass.getReplyContext(thread.Id).canReply);
            Assert.isNull(
                stoHelperClass.getReplyContext(thread.Id).inboxSenderLabel,
                'Keep legacy self items unchanged'
            );
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Legacy self reply'));
        }
        Assert.isTrue(stoHelperClass.getReplyContext(thread.Id).canReply, 'Internal agents retain their workflow');
        Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Agent reply'));
        stoHelperClass.closeThread(thread.Id);
        Test.stopTest();
    }

    @IsTest
    static void missingOriginalSenderMustNotGrantOwnerReplyAccess() {
        User childViewer = createChildViewer();
        Account owner = child();
        stoHelperClass.ThreadData info = childThreadData(null);
        info.cachedAccountId = owner.Id;
        info.cachedContactId = owner.PersonContactId;
        Thread__c thread = info.toThread();
        insert thread;
        insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = childViewer.Id, AccessLevel = 'Edit');
        Message__c original = new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Imported original message without contact',
            CRM_External_Message__c = true
        );
        insert original;
        // The before-insert defaults derive external status from ContactId; emulate a legacy import after defaults.
        original.CRM_External_Message__c = true;
        original.CRM_Sent_date__c = System.now().addDays(-1);
        Database.update(original, AccessLevel.SYSTEM_MODE);
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Later message is not the original sender',
            CRM_From_Contact__c = childViewer.ContactId
        );
        Test.startTest();
        assertCannotMutate(childViewer, thread.Id);
        Test.stopTest();
    }
}

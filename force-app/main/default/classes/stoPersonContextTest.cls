@IsTest
private class stoPersonContextTest {
    private class BarnMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        public Integer calls = 0;

        public BarnMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            calls++;
            Assert.areEqual('POST', request.getMethod());
            Assert.isTrue(request.getEndpoint().endsWith('/api/foreldreansvar/barn'));
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Assert.areEqual(new Set<String>{ 'ident' }, payload.keySet());
            Id actorAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
            String actorIdent = [
                SELECT INT_PersonIdent__c
                FROM Account
                WHERE Id = :actorAccountId
            ]
            .INT_PersonIdent__c;
            Assert.areEqual(actorIdent, payload.get('ident'), 'Always use the authenticated parent identity');
            HttpResponse response = new HttpResponse();
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
                    INT_DateOfBirth__c = String.valueOf(Date.today().addYears(ident == '12345678904' ? -8 : -12))
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
            SELECT Id, Name, PersonContactId, CRM_Person__c, CRM_Person__r.INT_DateOfBirth__c
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
        Thread__c thread = stoHelperClass.createThreadForPerson(
            'Familie',
            'For child',
            true,
            'STO',
            'Skriv til oss',
            'Familie',
            false,
            child.Id
        );
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
    static void rejectsUnrelatedAccounts() {
        stoPersonContext.testChildren = new List<Account>();
        Id childId = child().Id;
        try {
            stoHelperClass.createThreadForPerson('Familie', 'Denied', true, 'STO', null, null, false, childId);
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
        Account child = child();
        stoPersonContext.testChildren = new List<Account>{ child };
        for (Integer i = 0; i < 3; i++) {
            stoHelperClass.createThreadWithCase('Familie', 'Self', true, 'STO', null, null);
        }
        Test.startTest();
        Thread__c thread = stoHelperClass.createThreadForPerson(
            'Familie',
            'Child',
            true,
            'STO',
            null,
            null,
            false,
            child.Id
        );
        Assert.areEqual(child.Id, thread.CRM_Account__c);
        for (Integer i = 0; i < 2; i++) {
            stoHelperClass.createThreadForPerson('Familie', 'Child', true, 'STO', null, null, false, child.Id);
        }
        try {
            stoHelperClass.createThreadForPerson('Familie', 'Too many', true, 'STO', null, null, false, child.Id);
            Assert.fail('The child must have the same three-thread limit');
        } catch (stoHelperClass.maxThreadLimitReachedException expected) {
            Assert.areEqual(3, stoHelperClass.getOpenThreadsForPerson('Familie', 'STO', child.Id).size());
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
            thread = stoHelperClass.createThreadForPerson(
                'Familie',
                'Child inbox',
                true,
                'STO',
                null,
                null,
                false,
                child.Id
            );
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
    static void threeParentsGetTheirOwnChildrenAndCanCreateSto() {
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
        for (String parentIdent : parents.keySet()) {
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
                Thread__c created = stoHelperClass.createThreadForPerson(
                    'Familie',
                    'Foreldreansvar test',
                    true,
                    'STO',
                    'Skriv til oss',
                    'Familie og barn',
                    false,
                    beate.Id
                );
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
        }
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            Assert.areEqual(
                6,
                [SELECT COUNT() FROM Thread__Share WHERE ParentId IN :createdThreadIds AND AccessLevel = 'Read'],
                'Each new Beate thread must have two co-parent Read shares'
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
    static void metadataMocksSupplyRepresentableChildrenWithoutCallouts() {
        Map<String, User> parents = createFamilyParents();
        System.runAs(new User(Id = UserInfo.getUserId())) {
            List<API_Controller_Mock_Settings__c> settings = new List<API_Controller_Mock_Settings__c>();
            for (User parent : parents.values()) {
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
        Test.startTest();
        for (String parentIdent : parents.keySet()) {
            System.runAs(parents.get(parentIdent)) {
                List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
                Assert.areEqual(parentIdent == '12345678903' ? 1 : 2, options.size());
                Assert.areEqual(child().Id, stoPersonContext.resolveAccountId(child().Id));
                Assert.areEqual(child().PersonContactId, stoPersonContext.resolveContactId(child().Id));
                stoInboxHelper.getInboxPage(child().Id, null, null);
                Assert.areEqual(0, Limits.getCallouts(), 'ApiController must read custom metadata, not call PDL');
            }
        }
        Test.stopTest();
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
                stoHelperClass.createThreadForPerson('Familie', 'Denied', true, 'STO', null, null, false, childId);
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
                stoHelperClass.createThreadForPerson('Familie', 'Denied', true, 'STO', null, null, false, child().Id);
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

    private static Thread__c startThread(User starter, Id representedAccountId) {
        Thread__c thread;
        System.runAs(starter) {
            thread = stoHelperClass.createThreadForPerson(
                'Familie',
                'Original message',
                true,
                'STO',
                'Skriv til oss',
                'Familie',
                false,
                representedAccountId
            );
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
        Thread__c thread = startThread(parents.get('12345678902'), child().Id);
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
                Assert.areEqual(thread.Id, stoInboxHelper.getRecentThreadsForPerson(child().Id)[0].recordId);
                Assert.areEqual(
                    'Read',
                    [
                        SELECT AccessLevel
                        FROM Thread__Share
                        WHERE ParentId = :thread.Id AND UserOrGroupId = :parent.Id AND RowCause = 'Manual'
                    ]
                    .AccessLevel
                );
            }
        } else {
            insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = parent.Id, AccessLevel = 'Read');
        }
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            for (User otherParent : parents.values()) {
                System.runAs(otherParent) {
                    Assert.isFalse(CRM_MessageHelperExperience.getGroupedMessagesFromThread(thread.Id).isEmpty());
                }
                assertCannotMutate(otherParent, thread.Id);
            }
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
            thread = stoHelperClass.createThreadForPerson(
                'Familie',
                'Child BTO',
                true,
                'BTO',
                'Meld fra om endring',
                'Familie',
                false,
                null
            );
            Assert.isTrue(stoHelperClass.getReplyContext(thread.Id).canReply);
        }
        if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            for (String ident : new List<String>{ '12345678901', '12345678902' }) {
                System.runAs(parents.get(ident)) {
                    Assert.areEqual(thread.Id, stoInboxHelper.getRecentThreadsForPerson(son.Id)[0].recordId);
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
        Thread__c thread = stoHelperClass.createThread(
            null,
            'Familie',
            owner.Id,
            owner.PersonContactId,
            true,
            'STO',
            'Skriv til oss',
            'Familie',
            false
        );
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
        Thread__c thread = stoHelperClass.createThread(
            null,
            'Familie',
            owner.Id,
            owner.PersonContactId,
            true,
            'STO',
            'Skriv til oss',
            'Familie',
            false
        );
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

// Exercises the real eligibility query with isolated Person Accounts and mocked service responses, never live callouts.
@isTest
public with sharing class stoPersonContextTest {
    private static final String PARENT_IDENT = '12345678910';
    private static final String FIRST_CHILD_IDENT = '12345678904';
    private static final String SECOND_CHILD_IDENT = '12345678905';
    private static final String UNRETURNED_CHILD_IDENT = '12345678906';
    private static final String UNSHARED_CHILD_IDENT = '12345678907';
    private static final String BUSINESS_IDENT = '12345678990';
    private static final String UNKNOWN_IDENT = '12345678999';

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
            Assert.areEqual(PARENT_IDENT, payload.get('ident'), 'The service must receive the authenticated parent');

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setHeader('Content-Type', 'application/json');
            if (responseBody != null) {
                response.setBody(responseBody);
            }
            return response;
        }
    }

    private class VerificationMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        public Integer calls = 0;

        public VerificationMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest request) {
            calls++;
            Assert.areEqual('POST', request.getMethod());
            Assert.isTrue(request.getEndpoint().endsWith('/api/foreldreansvar/verifiser'));
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            Assert.areEqual(new Set<String>{ 'forelderIdent', 'barnIdent' }, payload.keySet());
            Assert.areEqual(PARENT_IDENT, payload.get('forelderIdent'), 'Verify the authenticated parent');
            Assert.areEqual(FIRST_CHILD_IDENT, payload.get('barnIdent'));
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setHeader('Content-Type', 'application/json');
            if (responseBody != null) {
                response.setBody(responseBody);
            }
            return response;
        }
    }

    @TestSetup
    static void setup() {
        List<Profile> fixtureProfiles = [
            SELECT Id
            FROM Profile
            WHERE
                Name = 'STO Test Community Login Profile'
                AND UserType = 'PowerCustomerSuccess'
                AND PermissionsViewAllData = FALSE
        ];
        Assert.areEqual(
            1,
            fixtureProfiles.size(),
            'Deploy the community test profile from force-app/test/profiles before running these tests'
        );
        PermissionSet fixtureAccess = new PermissionSet(
            Name = 'STO_Person_Context_Test_Access',
            Label = 'STO person context test access'
        );
        insert fixtureAccess;
        // Person Accounts require Contact read access before Account read access can be granted.
        insert new ObjectPermissions(ParentId = fixtureAccess.Id, SObjectType = 'Contact', PermissionsRead = true);
        insert new List<ObjectPermissions>{
            new ObjectPermissions(ParentId = fixtureAccess.Id, SObjectType = 'Account', PermissionsRead = true),
            new ObjectPermissions(ParentId = fixtureAccess.Id, SObjectType = 'Person__c', PermissionsRead = true),
            new ObjectPermissions(
                ParentId = fixtureAccess.Id,
                SObjectType = 'Thread__c',
                PermissionsRead = true,
                PermissionsCreate = true
            )
        };
        List<FieldPermissions> fixtureFields = new List<FieldPermissions>();
        for (
            String field : new List<String>{
                'Account.CRM_Person__c',
                'Account.INT_PersonIdent__c',
                'Person__c.INT_DateOfBirth__c',
                'Person__c.INT_Confidential__c'
            }
        ) {
            fixtureFields.add(
                new FieldPermissions(
                    ParentId = fixtureAccess.Id,
                    SObjectType = field.substringBefore('.'),
                    Field = field,
                    PermissionsRead = true
                )
            );
        }
        for (
            String field : new List<String>{
                'Thread__c.CRM_Contact__c',
                'Thread__c.CRM_Account__c',
                'Thread__c.CRM_Thread_Type__c',
                'Thread__c.STO_Category__c'
            }
        ) {
            fixtureFields.add(
                new FieldPermissions(
                    ParentId = fixtureAccess.Id,
                    SObjectType = 'Thread__c',
                    Field = field,
                    PermissionsRead = true,
                    PermissionsEdit = true
                )
            );
        }
        insert fixtureFields;
        UserRole ownerRole = new UserRole(Name = 'STO context ' + STO_TestDataFactory.generateRandomString(8));
        insert ownerRole;
        User owner = (User) STO_TestDataFactory.createRecord(
            new User(
                UserRoleId = ownerRole.Id,
                ProfileId = UserInfo.getProfileId(),
                TimeZoneSidKey = UserInfo.getTimeZone().getID()
            )
        );
        System.runAs(owner) {
            STO_TestDataFactory.createRecordList(
                new List<SObject>{
                    person(PARENT_IDENT, 'Parent', 35),
                    person(FIRST_CHILD_IDENT, 'Alpha', 8),
                    person(SECOND_CHILD_IDENT, 'Bravo', 12),
                    person(UNRETURNED_CHILD_IDENT, 'Unreturned', 7),
                    person(UNSHARED_CHILD_IDENT, 'Unshared', 9)
                }
            );
            Account firstChild = account(FIRST_CHILD_IDENT);
            Map<Id, Schema.RecordTypeInfo> accountRecordTypes = Account.SObjectType.getDescribe()
                .getRecordTypeInfosById();
            Id businessRecordTypeId;
            for (RecordType recordType : [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account' AND IsPersonType = FALSE AND IsActive = TRUE
            ]) {
                if (accountRecordTypes.get(recordType.Id).isAvailable()) {
                    businessRecordTypeId = recordType.Id;
                    break;
                }
            }
            Assert.isNotNull(
                businessRecordTypeId,
                'The fixture owner must have an available business Account record type'
            );
            insert new Account(
                Name = 'Business candidate',
                RecordTypeId = businessRecordTypeId,
                INT_PersonIdent__c = BUSINESS_IDENT,
                CRM_Person__c = firstChild.CRM_Person__c
            );
            Account parentAccount = account(PARENT_IDENT);
            update new Account(Id = parentAccount.Id, OwnerId = owner.Id);
            User parent = new User(
                Username = 'sto.context.' + UserInfo.getOrganizationId() + '.' + parentAccount.Id + '@example.test',
                Email = 'parent@example.test',
                LastName = 'Parent',
                Alias = 'stoctx',
                CommunityNickname = 'sto-context-' + parentAccount.Id,
                ProfileId = fixtureProfiles[0].Id,
                ContactId = parentAccount.PersonContactId,
                TimeZoneSidKey = owner.TimeZoneSidKey,
                LocaleSidKey = 'no_NO',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'no'
            );
            // Setup-record DML is isolated with runAs, as in the existing community-user tests.
            System.runAs(new User(Id = owner.Id)) {
                insert parent;
                // Schema access does not grant record access; the explicit Read shares below remain required.
                insert new List<PermissionSetAssignment>{
                    new PermissionSetAssignment(AssigneeId = parent.Id, PermissionSetId = fixtureAccess.Id),
                    new PermissionSetAssignment(
                        AssigneeId = parent.Id,
                        PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Experience' LIMIT 1]
                        .Id
                    )
                };
            }
            insert new API_Controller_Mock_Settings__c(
                SetupOwnerId = parent.Id,
                Use_Mock__c = false,
                Status__c = 'OK',
                Status_Code__c = '200'
            );

            Set<String> sharedIdents = new Set<String>{
                FIRST_CHILD_IDENT,
                SECOND_CHILD_IDENT,
                UNRETURNED_CHILD_IDENT,
                BUSINESS_IDENT
            };
            List<AccountShare> accountShares = new List<AccountShare>();
            List<Person__Share> personShares = new List<Person__Share>();
            Set<Id> sharedPersonIds = new Set<Id>();
            for (Account candidate : [
                SELECT Id, CRM_Person__c
                FROM Account
                WHERE INT_PersonIdent__c IN :sharedIdents
            ]) {
                accountShares.add(
                    new AccountShare(
                        AccountId = candidate.Id,
                        UserOrGroupId = parent.Id,
                        AccountAccessLevel = 'Read',
                        OpportunityAccessLevel = 'None',
                        CaseAccessLevel = 'None'
                    )
                );
                if (!sharedPersonIds.contains(candidate.CRM_Person__c)) {
                    sharedPersonIds.add(candidate.CRM_Person__c);
                    personShares.add(
                        new Person__Share(
                            ParentId = candidate.CRM_Person__c,
                            UserOrGroupId = parent.Id,
                            AccessLevel = 'Read'
                        )
                    );
                }
            }
            insert accountShares;
            insert personShares;
        }
    }

    private static Person__c person(String ident, String lastName, Integer age) {
        return new Person__c(
            Name = ident,
            INT_FirstName__c = 'Test',
            INT_LastName__c = lastName,
            INT_Sex__c = 'Mann',
            INT_Confidential__c = 'UGRADERT',
            INT_DateOfBirth__c = String.valueOf(Date.today().addYears(-age))
        );
    }

    private static Account account(String ident) {
        return [
            SELECT Id, Name, IsPersonAccount, PersonContactId, INT_PersonIdent__c, CRM_Person__c
            FROM Account
            WHERE INT_PersonIdent__c = :ident
            LIMIT 1
        ];
    }

    private static User parent() {
        Id parentAccountId = account(PARENT_IDENT).Id;
        return [SELECT Id, AccountId, ContactId FROM User WHERE AccountId = :parentAccountId LIMIT 1];
    }

    private static String barnBody(List<String> idents) {
        List<Object> children = new List<Object>();
        for (String ident : idents) {
            children.add(new Map<String, Object>{ 'ident' => ident });
        }
        return JSON.serialize(new Map<String, Object>{ 'barn' => children });
    }

    private static void assertReturnedAccounts(List<stoPersonContext.PersonOption> options, Set<String> idents) {
        Map<Id, Account> expectedAccounts = new Map<Id, Account>(
            [
                SELECT Id, CRM_Person__r.Name
                FROM Account
                WHERE IsPersonAccount = TRUE AND CRM_Person__r.Name IN :idents
            ]
        );
        Assert.areEqual(idents.size(), expectedAccounts.size(), 'All expected test accounts must be accessible');
        Assert.areEqual(expectedAccounts.size(), options.size(), 'Return only matching eligible Person Accounts');
        Set<Id> actualAccountIds = new Set<Id>();
        for (stoPersonContext.PersonOption option : options) {
            actualAccountIds.add(option.value);
            Assert.isTrue(expectedAccounts.containsKey(option.value), 'Do not expose another account');
            Assert.areEqual(expectedAccounts.get(option.value).CRM_Person__r.Name, option.representedPersonIdentifier);
        }
        Assert.areEqual(expectedAccounts.keySet(), actualAccountIds);
    }

    @isTest
    static void validBarnMatchesAccountsAndCachesResponseTest() {
        User viewer = parent();
        Account firstChild = account(FIRST_CHILD_IDENT);
        BarnMock mock = new BarnMock(
            200,
            barnBody(
                new List<String>{
                    SECOND_CHILD_IDENT,
                    FIRST_CHILD_IDENT,
                    FIRST_CHILD_IDENT,
                    UNKNOWN_IDENT,
                    BUSINESS_IDENT,
                    UNSHARED_CHILD_IDENT
                }
            )
        );
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE INT_PersonIdent__c = :UNRETURNED_CHILD_IDENT]);
            Assert.isFalse(account(BUSINESS_IDENT).IsPersonAccount);
            Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE INT_PersonIdent__c = :UNSHARED_CHILD_IDENT]);
            List<stoPersonContext.PersonOption> options = stoPersonContext.getRepresentableChildren();
            assertReturnedAccounts(options, new Set<String>{ FIRST_CHILD_IDENT, SECOND_CHILD_IDENT });
            Assert.areEqual(firstChild.Id, options[0].value, 'Options remain sorted by Salesforce account name');
            Assert.areEqual(firstChild.Name + ' (8 år)', options[0].label);
            assertReturnedAccounts(
                stoPersonContext.getRepresentableChildren(),
                new Set<String>{ FIRST_CHILD_IDENT, SECOND_CHILD_IDENT }
            );
        }
        Assert.areEqual(1, mock.calls, 'Reuse the service response within the same user transaction');
        Test.stopTest();
    }

    private static void assertNoChildren(Integer statusCode, String body) {
        User viewer = parent();
        BarnMock mock = new BarnMock(statusCode, body);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE INT_PersonIdent__c = :FIRST_CHILD_IDENT]);
            assertReturnedAccounts(stoPersonContext.getRepresentableChildren(), new Set<String>());
            assertReturnedAccounts(stoPersonContext.getRepresentableChildren(), new Set<String>());
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void emptyBarnListReturnsNoChildrenTest() {
        assertNoChildren(200, '{"barn":[]}');
    }

    @isTest
    static void noContentReturnsNoChildrenTest() {
        assertNoChildren(204, null);
    }

    @isTest
    static void parentNotFoundReturnsNoChildrenTest() {
        assertNoChildren(404, null);
    }

    @isTest
    static void unknownChildDoesNotMatchAnAccountTest() {
        assertNoChildren(200, barnBody(new List<String>{ UNKNOWN_IDENT }));
    }

    private static void assertInvalidBarnResponse(String body) {
        User viewer = parent();
        BarnMock mock = new BarnMock(200, body);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            try {
                stoPersonContext.getRepresentableChildren();
                Assert.fail('An invalid service response must surface an error, not an empty successful list');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected.getMessage());
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void blankBodyIsAnErrorTest() {
        assertInvalidBarnResponse(' ');
    }

    @isTest
    static void missingBodyIsAnErrorTest() {
        assertInvalidBarnResponse(null);
    }

    @isTest
    static void malformedJsonIsAnErrorTest() {
        assertInvalidBarnResponse('not json');
    }

    @isTest
    static void nullResponseIsAnErrorTest() {
        assertInvalidBarnResponse('null');
    }

    @isTest
    static void missingBarnListIsAnErrorTest() {
        assertInvalidBarnResponse('{}');
    }

    @isTest
    static void nullBarnListIsAnErrorTest() {
        assertInvalidBarnResponse('{"barn":null}');
    }

    @isTest
    static void invalidBarnListTypeIsAnErrorTest() {
        assertInvalidBarnResponse('{"barn":{}}');
    }

    @isTest
    static void nullChildIsAnErrorTest() {
        assertInvalidBarnResponse('{"barn":[null]}');
    }

    @isTest
    static void missingChildIdentIsAnErrorTest() {
        assertInvalidBarnResponse('{"barn":[{"ident":"12345678904"},{}]}');
    }

    @isTest
    static void blankChildIdentIsAnErrorTest() {
        assertInvalidBarnResponse('{"barn":[{"ident":" "}]}');
    }

    @isTest
    static void serviceFailureIsNotAnEmptySuccessTest() {
        User viewer = parent();
        BarnMock mock = new BarnMock(500, '{"title":"Internal Server Error"}');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            try {
                stoPersonContext.getRepresentableChildren();
                Assert.fail('A service failure must surface an error');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.isTrue(expected.getMessage().contains('LoggId'));
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void eighteenthBirthdayBoundaryTest() {
        User viewer = parent();
        Person__c child = [SELECT Id, INT_DateOfBirth__c FROM Person__c WHERE Name = :FIRST_CHILD_IDENT];
        BarnMock mock = new BarnMock(200, barnBody(new List<String>{ FIRST_CHILD_IDENT }));
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            assertReturnedAccounts(stoPersonContext.getRepresentableChildren(), new Set<String>{ FIRST_CHILD_IDENT });
        }
        Date adultBirthDate = Date.today().addYears(-18);
        for (Date birthDate : new List<Date>{ adultBirthDate.addDays(1), adultBirthDate, adultBirthDate.addDays(-1) }) {
            child.INT_DateOfBirth__c = String.valueOf(birthDate);
            update child;
            System.runAs(viewer) {
                assertReturnedAccounts(
                    stoPersonContext.getRepresentableChildren(),
                    birthDate > adultBirthDate ? new Set<String>{ FIRST_CHILD_IDENT } : new Set<String>()
                );
            }
        }
        Assert.areEqual(1, mock.calls, 'Each call rechecks the real eligibility query, not cached test children');
        Test.stopTest();
    }

    @isTest
    static void birthDateMustNotBeFutureOrMissingTest() {
        User viewer = parent();
        Person__c child = [SELECT Id, INT_DateOfBirth__c FROM Person__c WHERE Name = :FIRST_CHILD_IDENT];
        BarnMock mock = new BarnMock(200, barnBody(new List<String>{ FIRST_CHILD_IDENT }));
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            assertReturnedAccounts(stoPersonContext.getRepresentableChildren(), new Set<String>{ FIRST_CHILD_IDENT });
        }
        for (Date birthDate : new List<Date>{ Date.today(), Date.today().addDays(1), null }) {
            child.INT_DateOfBirth__c = birthDate == null ? null : String.valueOf(birthDate);
            update child;
            System.runAs(viewer) {
                assertReturnedAccounts(
                    stoPersonContext.getRepresentableChildren(),
                    birthDate == Date.today() ? new Set<String>{ FIRST_CHILD_IDENT } : new Set<String>()
                );
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void protectedChildrenAreNotRepresentableTest() {
        User viewer = parent();
        Person__c child = [SELECT Id, INT_Confidential__c FROM Person__c WHERE Name = :FIRST_CHILD_IDENT];
        BarnMock mock = new BarnMock(200, barnBody(new List<String>{ FIRST_CHILD_IDENT }));
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            assertReturnedAccounts(stoPersonContext.getRepresentableChildren(), new Set<String>{ FIRST_CHILD_IDENT });
        }
        for (String confidentiality : new List<String>{ 'FORTROLIG', 'STRENGT_FORTROLIG', 'UGRADERT' }) {
            child.INT_Confidential__c = confidentiality;
            update child;
            // Protection changes can revoke manual Person shares; restore only the unprotected fixture's access.
            if (
                confidentiality == 'UGRADERT' &&
                [SELECT COUNT() FROM Person__Share WHERE ParentId = :child.Id AND UserOrGroupId = :viewer.Id] == 0
            ) {
                insert new Person__Share(ParentId = child.Id, UserOrGroupId = viewer.Id, AccessLevel = 'Read');
            }
            System.runAs(viewer) {
                assertReturnedAccounts(
                    stoPersonContext.getRepresentableChildren(),
                    confidentiality == 'UGRADERT' ? new Set<String>{ FIRST_CHILD_IDENT } : new Set<String>()
                );
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    private static stoHelperClass.ThreadData representedThreadData() {
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.representedPersonIdentifier = FIRST_CHILD_IDENT;
        info.type = 'STO';
        info.theme = 'Familie';
        info.inboxTitle = 'Skriv til oss';
        info.inboxTheme = 'Familie og barn';
        info.msgText = 'A message on behalf of the child';
        info.medskriv = true;
        return info;
    }

    private static void assertVerificationResult(Integer statusCode, String body, Boolean expected) {
        User viewer = parent();
        VerificationMock mock = new VerificationMock(statusCode, body);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            Assert.areEqual(expected, representedThreadData().validateRepresentation());
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void representationUsesAuthenticatedParentTest() {
        assertVerificationResult(200, '{"kanRepresentere":true}', true);
    }

    @isTest
    static void negativeVerificationPreventsThreadCreationTest() {
        User viewer = parent();
        VerificationMock mock = new VerificationMock(200, '{"kanRepresentere":false}');
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            try {
                stoHelperClass.createThread(representedThreadData());
                Assert.fail('A negative verification must prevent child submission');
            } catch (stoHelperClass.NoParentalResponsibilityException expected) {
                Assert.areEqual(0, [SELECT COUNT() FROM Thread__c]);
                Assert.areEqual(0, [SELECT COUNT() FROM Message__c]);
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void noVerificationContentDoesNotAuthorizeTest() {
        assertVerificationResult(204, null, false);
    }

    @isTest
    static void verificationParentNotFoundDoesNotAuthorizeTest() {
        assertVerificationResult(404, null, false);
    }

    private static void assertInvalidVerification(String body) {
        User viewer = parent();
        VerificationMock mock = new VerificationMock(200, body);
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            try {
                representedThreadData().validateRepresentation();
                Assert.fail('Malformed verification must surface an error, not authorize a submission');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected.getMessage());
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void blankVerificationIsAnErrorTest() {
        assertInvalidVerification(' ');
    }

    @isTest
    static void malformedVerificationIsAnErrorTest() {
        assertInvalidVerification('not json');
    }

    @isTest
    static void nullVerificationIsAnErrorTest() {
        assertInvalidVerification('null');
    }

    @isTest
    static void missingVerificationFlagIsAnErrorTest() {
        assertInvalidVerification('{}');
    }

    @isTest
    static void nonBooleanVerificationFlagIsAnErrorTest() {
        assertInvalidVerification('{"kanRepresentere":"true"}');
    }

    @isTest
    static void selfSubmissionSkipsChildVerificationTest() {
        User viewer = parent();
        Test.startTest();
        System.runAs(viewer) {
            stoHelperClass.ThreadData info = representedThreadData();
            info.representedPersonIdentifier = null;
            Assert.isTrue(info.validateRepresentation());
            Thread__c thread = stoHelperClass.createThreadWithCaseV2(
                info.theme,
                info.msgText,
                info.medskriv,
                info.type,
                info.inboxTitle,
                info.inboxTheme,
                info.disabilityCampaign
            );
            Assert.areEqual(viewer.AccountId, thread.CRM_Account__c);
            Assert.areEqual(viewer.ContactId, thread.CRM_Contact__c);
            Assert.areEqual(1, [SELECT COUNT() FROM Message__c WHERE CRM_Thread__c = :thread.Id]);
            Assert.areEqual(0, Limits.getCallouts());
        }
        Test.stopTest();
    }

    @isTest
    static void representedChildRemainsSubjectButParentIsMessageSenderTest() {
        User viewer = parent();
        Account child = account(FIRST_CHILD_IDENT);
        Test.startTest();
        System.runAs(viewer) {
            stoHelperClass.ThreadData info = representedThreadData();
            Thread__c thread = info.toThread();
            Assert.areEqual(child.Id, thread.CRM_Account__c);
            Assert.areEqual(child.PersonContactId, thread.CRM_Contact__c);
            insert thread;
            stoHelperClass.createMessage(thread, info);
            Message__c message = [
                SELECT CRM_From_Contact__c
                FROM Message__c
                WHERE CRM_Thread__c = :thread.Id
                LIMIT 1
            ];
            Assert.areEqual(viewer.ContactId, message.CRM_From_Contact__c);
        }
        Test.stopTest();
    }

    private static Thread__c lookupThread(Account subject, String category, String type, Boolean withMessage) {
        stoHelperClass.ThreadData info = new stoHelperClass.ThreadData();
        info.cachedAccountId = subject.Id;
        info.cachedContactId = subject.PersonContactId;
        info.theme = category;
        info.type = type;
        info.msgText = 'Open thread lookup test';
        info.medskriv = true;
        Thread__c thread = info.toThread();
        insert thread;
        if (type == 'STB') {
            thread.CRM_Thread_Type__c = type;
            update thread;
        }
        if (withMessage) {
            stoHelperClass.createMessage(thread, info);
        }
        return thread;
    }

    @isTest
    static void openThreadLookupForSelfFiltersAndPreservesLegacyTypesTest() {
        User viewer = parent();
        Account self = account(PARENT_IDENT);
        System.runAs(viewer) {
            Thread__c sto = lookupThread(self, 'Familie', 'STO', true);
            Thread__c legacy = lookupThread(self, 'Familie', 'STB', true);
            Thread__c bto = lookupThread(self, 'Familie', 'BTO', true);

            Test.startTest();
            List<stoInboxHelper.thread> threads = stoHelperClass.getAccessibleOpenThreadsForPerson(
                'Familie',
                'STO',
                null
            );
            Set<Id> actualIds = new Set<Id>();
            for (stoInboxHelper.thread item : threads) {
                actualIds.add(item.recordId);
                Assert.isNotNull(item.latestmessage);
                Assert.areEqual('Åpen', item.status);
                Assert.isNull(item.inboxSenderLabel, 'The sender does not need a label for their own threads');
            }
            Assert.areEqual(new Set<Id>{ sto.Id, legacy.Id }, actualIds);
            List<stoInboxHelper.thread> btoThreads = stoHelperClass.getAccessibleOpenThreadsForPerson(
                'Familie',
                'BTO',
                self.Id
            );
            Assert.areEqual(1, btoThreads.size());
            Assert.areEqual(bto.Id, btoThreads[0].recordId);
            Assert.areEqual(3, stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'ALL', self.Id).size());
            Assert.areEqual(0, Limits.getCallouts(), 'Self lookup must not call the family service');
            Test.stopTest();
        }
    }

    @isTest
    static void openThreadLookupExcludesClosedOtherCategoryAndOtherPersonTest() {
        User viewer = parent();
        Account self = account(PARENT_IDENT);
        Account child = account(FIRST_CHILD_IDENT);
        System.runAs(viewer) {
            Thread__c closed = lookupThread(self, 'Familie', 'STO', true);
            stoHelperClass.closeThread(closed.Id);
            lookupThread(self, 'Arbeid', 'STO', true);
            lookupThread(child, 'Familie', 'STO', true);
            Test.startTest();
            Assert.areEqual(0, stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', null).size());
            Test.stopTest();
        }
    }

    @isTest
    static void openThreadLookupReturnsEmptyListButLegacyKeepsNullTest() {
        User viewer = parent();
        System.runAs(viewer) {
            Test.startTest();
            Assert.areEqual(0, stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', null).size());
            Assert.isNull(stoHelperClass.getOpenThreads('Familie', 'STO'));
            lookupThread(account(PARENT_IDENT), 'Familie', 'STO', false);
            Assert.areEqual(
                0,
                stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', viewer.AccountId).size(),
                'A thread without a displayable message must not leave a null card'
            );
            Test.stopTest();
        }
    }

    @isTest
    static void openThreadLookupAuthorizesSelectedChildTest() {
        User viewer = parent();
        Account child = account(FIRST_CHILD_IDENT);
        BarnMock mock = new BarnMock(200, barnBody(new List<String>{ FIRST_CHILD_IDENT }));
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            // Resolve the child before message DML; subsequent lookups reuse the transaction's service response.
            stoPersonContext.getRepresentableChildren();
            Thread__c childThread = lookupThread(child, 'Familie', 'STO', true);
            lookupThread(account(PARENT_IDENT), 'Familie', 'STO', true);
            List<stoInboxHelper.thread> threads = stoHelperClass.getAccessibleOpenThreadsForPerson(
                'Familie',
                'STO',
                child.Id
            );
            Assert.areEqual(1, threads.size());
            Assert.areEqual(childThread.Id, threads[0].recordId);
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void openThreadLookupRejectsUnrelatedAndInvisibleAccountsTest() {
        User viewer = parent();
        Set<Id> rejectedAccountIds = new Set<Id>{
            account(UNRETURNED_CHILD_IDENT).Id,
            account(UNSHARED_CHILD_IDENT).Id,
            account(BUSINESS_IDENT).Id
        };
        BarnMock mock = new BarnMock(
            200,
            barnBody(new List<String>{ FIRST_CHILD_IDENT, UNSHARED_CHILD_IDENT, BUSINESS_IDENT })
        );
        Test.setMock(HttpCalloutMock.class, mock);
        Test.startTest();
        System.runAs(viewer) {
            for (Id selectedAccountId : rejectedAccountIds) {
                try {
                    stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', selectedAccountId);
                    Assert.fail('Visibility or a caller-supplied ID alone must not authorize a selected person');
                } catch (AuraHandledException error) {
                    Assert.areEqual('Du har ikke tilgang til samtalene for denne personen.', error.getMessage());
                }
            }
        }
        Assert.areEqual(1, mock.calls);
        Test.stopTest();
    }

    @isTest
    static void openThreadLookupDoesNotHideFamilyServiceFailureTest() {
        User viewer = parent();
        Id childId = account(FIRST_CHILD_IDENT).Id;
        Test.setMock(HttpCalloutMock.class, new BarnMock(500, '{"error":"unavailable"}'));
        Test.startTest();
        System.runAs(viewer) {
            try {
                stoHelperClass.getAccessibleOpenThreadsForPerson('Familie', 'STO', childId);
                Assert.fail('A service failure must surface instead of allowing an empty-list submission');
            } catch (NKS_ForeldreansvarService.ForeldreansvarException expected) {
                Assert.isNotNull(expected.getMessage());
            }
        }
        Test.stopTest();
    }

    @isTest
    static void currentUserCacheIsScopedToTheAuthenticatedActor() {
        User parentUser = parent();
        Id originalUserId = UserInfo.getUserId();
        Test.startTest();
        Assert.areEqual(originalUserId, stoPersonContext.currentUser().Id);
        System.runAs(parentUser) {
            Assert.areEqual(parentUser.Id, stoPersonContext.currentUser().Id);
            Assert.areEqual(account(PARENT_IDENT).PersonContactId, stoPersonContext.currentUser().ContactId);
            Integer beforeRepeat = Limits.getQueries();
            stoPersonContext.currentUser();
            Assert.areEqual(beforeRepeat, Limits.getQueries(), 'Repeated identity reads must not run SOQL');
        }
        Assert.areEqual(originalUserId, stoPersonContext.currentUser().Id);
        Test.stopTest();
    }

    @isTest
    static void personOptionAgeTest() {
        Map<Date, Integer> expectedAges = new Map<Date, Integer>{
            Date.today().addYears(-8).addDays(1) => 7,
            Date.today().addYears(-8) => 8,
            Date.today().addYears(-8).addDays(-1) => 8
        };
        for (Date birthDate : expectedAges.keySet()) {
            Account child = new Account(
                Id = '001000000000001AAA',
                Name = 'Barn',
                INT_PersonIdent__c = '12345678910',
                CRM_Person__r = new Person__c(Name = '12345678910', INT_DateOfBirth__c = String.valueOf(birthDate))
            );
            stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

            Assert.areEqual('Barn (' + expectedAges.get(birthDate) + ' år)', option.label);
            Assert.areEqual(child.Id, option.value);
            Assert.areEqual(child.CRM_Person__r.Name, option.representedPersonIdentifier);
        }
    }

    @isTest
    static void personOptionWithoutBirthDateTest() {
        Account child = new Account(
            Id = '001000000000001AAA',
            Name = 'Barn',
            CRM_Person__r = new Person__c(Name = '12345678910')
        );
        stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

        Assert.areEqual('Barn', option.label);
        Assert.areEqual(child.Id, option.value);
        Assert.areEqual(child.CRM_Person__r.Name, option.representedPersonIdentifier);
    }

    @isTest
    static void personOptionUsesPersonIdentifierInsteadOfAccountCopyTest() {
        Account child = new Account(
            Id = '001000000000001AAA',
            Name = 'Barn',
            INT_PersonIdent__c = '12345678999',
            CRM_Person__r = new Person__c(Name = '12345678910')
        );
        stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

        Assert.areEqual('12345678910', option.representedPersonIdentifier);
    }
}

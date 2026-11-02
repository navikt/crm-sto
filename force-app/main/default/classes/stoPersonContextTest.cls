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

    @TestSetup
    static void setup() {
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
            insert new Account(
                Name = 'Business candidate',
                RecordTypeId = [
                    SELECT Id
                    FROM RecordType
                    WHERE SObjectType = 'Account' AND IsPersonType = FALSE AND IsActive = TRUE
                    LIMIT 1
                ]
                .Id,
                INT_PersonIdent__c = BUSINESS_IDENT,
                CRM_Person__c = firstChild.CRM_Person__c
            );
            Account parentAccount = account(PARENT_IDENT);
            parentAccount.OwnerId = owner.Id;
            update parentAccount;
            User parent = new User(
                Username = 'sto.context.' + UserInfo.getOrganizationId() + '.' + parentAccount.Id + '@example.test',
                Email = 'parent@example.test',
                LastName = 'Parent',
                Alias = 'stoctx',
                CommunityNickname = 'sto-context-' + parentAccount.Id,
                ProfileId = [
                    SELECT Id
                    FROM Profile
                    WHERE UserType = 'PowerCustomerSuccess' AND PermissionsViewAllData = FALSE
                    LIMIT 1
                ]
                .Id,
                ContactId = parentAccount.PersonContactId,
                TimeZoneSidKey = owner.TimeZoneSidKey,
                LocaleSidKey = 'no_NO',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'no'
            );
            // Setup-record DML is isolated with runAs, as in the existing community-user tests.
            System.runAs(new User(Id = owner.Id)) {
                insert parent;
            }
            insert new API_Controller_Mock_Settings__c(SetupOwnerId = parent.Id, Use_Mock__c = false);

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
            [SELECT Id, INT_PersonIdent__c FROM Account WHERE INT_PersonIdent__c IN :idents]
        );
        Assert.areEqual(idents.size(), expectedAccounts.size(), 'All expected test accounts must be accessible');
        Assert.areEqual(expectedAccounts.size(), options.size(), 'Return only matching eligible Person Accounts');
        Set<Id> actualAccountIds = new Set<Id>();
        for (stoPersonContext.PersonOption option : options) {
            actualAccountIds.add(option.value);
            Assert.isTrue(expectedAccounts.containsKey(option.value), 'Do not expose another account');
            Assert.areEqual(expectedAccounts.get(option.value).INT_PersonIdent__c, option.representedPersonIdentifier);
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
                CRM_Person__r = new Person__c(INT_DateOfBirth__c = String.valueOf(birthDate))
            );
            stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

            Assert.areEqual('Barn (' + expectedAges.get(birthDate) + ' år)', option.label);
            Assert.areEqual(child.Id, option.value);
            Assert.areEqual(child.INT_PersonIdent__c, option.representedPersonIdentifier);
        }
    }

    @isTest
    static void personOptionWithoutBirthDateTest() {
        Account child = new Account(Id = '001000000000001AAA', Name = 'Barn', INT_PersonIdent__c = '12345678910');
        stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

        Assert.areEqual('Barn', option.label);
        Assert.areEqual(child.Id, option.value);
        Assert.areEqual(child.INT_PersonIdent__c, option.representedPersonIdentifier);
    }
}

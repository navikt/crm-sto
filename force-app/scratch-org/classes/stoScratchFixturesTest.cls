@IsTest
private class stoScratchFixturesTest {
    @TestSetup
    static void setup() {
        Test.startTest();
        UserRole role = new UserRole(Name = 'Scratch fixtures');
        insert role;
        User owner = (User) STO_TestDataFactory.createRecord(
            new User(UserRoleId = role.Id, ProfileId = UserInfo.getProfileId(), TimeZoneSidKey = 'Europe/Oslo')
        );
        System.runAs(owner) {
            Set<String> identities = new Set<String>{
                '12345678901',
                '12345678902',
                '12345678903',
                '12345678904',
                '12345678905'
            };
            Set<String> childIdentities = new Set<String>{ '12345678904', '12345678905' };
            for (String ident : identities) {
                STO_TestDataFactory.createRecord(
                    new Person__c(
                        Name = ident,
                        INT_FirstName__c = 'Fixture',
                        INT_LastName__c = 'Person',
                        INT_Confidential__c = 'UGRADERT',
                        INT_DateOfBirth__c = childIdentities.contains(ident) ? '2018-01-01' : '1980-01-01'
                    )
                );
            }
            Id profileId = [SELECT Id FROM Profile WHERE Name = 'Scratch Community Login Profile'].Id;
            List<Account> accounts = [
                SELECT Id, PersonContactId, INT_PersonIdent__c, CRM_Person__c
                FROM Account
                WHERE INT_PersonIdent__c IN :identities
            ];
            List<User> viewers = new List<User>();
            for (Account account : accounts) {
                viewers.add(
                    new User(
                        Username = 'scratch-fixture.' + account.Id + '@example.test',
                        Email = 'fixture@example.test',
                        LastName = 'Fixture',
                        Alias = account.INT_PersonIdent__c == '12345678901' ? 'fixture' : 'fx' + viewers.size(),
                        CommunityNickname = 'fixture-' + account.Id,
                        ContactId = account.PersonContactId,
                        ProfileId = profileId,
                        TimeZoneSidKey = 'Europe/Oslo',
                        LocaleSidKey = 'en_US',
                        EmailEncodingKey = 'UTF-8',
                        LanguageLocaleKey = 'en_US'
                    )
                );
            }
            System.runAs(new User(Id = owner.Id)) {
                insert viewers;
                List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
                for (PermissionSet permission : [
                    SELECT Id
                    FROM PermissionSet
                    WHERE Name IN ('STO_Experience', 'STO_Scratch_Fixtures')
                ]) {
                    for (User viewer : viewers) {
                        assignments.add(
                            new PermissionSetAssignment(AssigneeId = viewer.Id, PermissionSetId = permission.Id)
                        );
                    }
                }
                insert assignments;
            }
            List<AccountShare> accountShares = new List<AccountShare>();
            List<Person__Share> personShares = new List<Person__Share>();
            for (User viewer : viewers) {
                for (Account fixture : accounts) {
                    Boolean ownAccount = fixture.PersonContactId == viewer.ContactId;
                    if (ownAccount || childIdentities.contains(fixture.INT_PersonIdent__c)) {
                        personShares.add(
                            new Person__Share(
                                ParentId = fixture.CRM_Person__c,
                                UserOrGroupId = viewer.Id,
                                AccessLevel = 'Read'
                            )
                        );
                        if (!ownAccount) {
                            accountShares.add(
                                new AccountShare(
                                    AccountId = fixture.Id,
                                    UserOrGroupId = viewer.Id,
                                    AccountAccessLevel = 'Read',
                                    OpportunityAccessLevel = 'None',
                                    CaseAccessLevel = 'None'
                                )
                            );
                        }
                    }
                }
            }
            insert accountShares;
            insert personShares;
        }
        Test.stopTest();
    }

    private static User viewer() {
        return [SELECT Id, AccountId FROM User WHERE Alias = 'fixture' AND IsPortalEnabled = TRUE LIMIT 1];
    }

    @IsTest
    static void mockFamilyAndInbox() {
        User viewer = viewer();
        Test.startTest();
        System.runAs(viewer) {
            Assert.isTrue(stoScratchSupport.isEnabled());
            List<stoPersonContext.PersonOption> children = stoPersonContext.getRepresentableChildren();
            Assert.areEqual(2, children.size());
            Assert.areEqual(
                'Beate Normann (8 år)',
                children[0].label,
                'Scratch responses must contain service mock details, not the differently named Salesforce fixtures'
            );
            Assert.areEqual('Ola Normann (12 år)', children[1].label);
            Assert.isTrue(stoPersonContext.verifyRepresentation('12345678904'));
            Assert.isFalse(stoPersonContext.verifyRepresentation('99999999999'));
            Assert.areEqual(
                0,
                Limits.getCallouts(),
                'Opted-in scratch fixtures must retain simulated family responses'
            );
            HttpResponse response = (HttpResponse) stoScratchSupport.invoke(
                'barn',
                new Map<String, Object>{ 'parentIdent' => '12345678901' }
            );
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            Map<String, Object> firstChild = (Map<String, Object>) ((List<Object>) body.get('barn'))[0];
            Assert.areEqual('Beate', firstChild.get('fornavn'));
            Assert.areEqual('Normann', firstChild.get('etternavn'));
            Assert.areEqual('2018-10-18', firstChild.get('foedselsdato'));
            Assert.areEqual(2018, firstChild.get('foedselsaar'));
            Assert.areEqual(8, firstChild.get('alder'));
            Map<String, Object> page = stoInboxHelper.getAccessibleInboxPage(null, null, null);
            Assert.areEqual(0, ((List<Object>) page.get('recent')).size());
            Assert.areEqual(0, ((List<Object>) page.get('older')).size());
            Assert.areEqual(false, page.get('hasMore'));
            Assert.areEqual(false, stoInboxHelper.getNextInboxPage(null, null, null).get('hasMore'));
            Id childId = [SELECT Id FROM Account WHERE INT_PersonIdent__c = '12345678904'].Id;
            Assert.areEqual(false, stoInboxHelper.getAccessibleInboxPage(childId, null, null).get('hasMore'));
        }
        Test.stopTest();
    }

    @IsTest
    static void rejectsDisabledAdapterAndForgedActor() {
        Assert.isFalse(stoScratchSupport.isEnabled(), 'The internal admin is not opted in.');
        try {
            new stoScratchFixtures().call('inbox', new Map<String, Object>());
            Assert.fail('A direct call must not bypass opt-in.');
        } catch (AuraHandledException expected) {
            Assert.isNotNull(expected);
        }
        System.runAs(viewer()) {
            for (String action : new List<String>{ 'barn', 'verifiser' }) {
                try {
                    stoScratchSupport.invoke(
                        action,
                        new Map<String, Object>{ 'parentIdent' => '12345678902', 'childIdent' => '12345678904' }
                    );
                    Assert.fail('The caller cannot impersonate another fixture parent.');
                } catch (AuraHandledException expected) {
                    Assert.isNotNull(expected);
                }
            }
        }
    }

    @IsTest
    static void allFiveUsersFollowDocumentedRelationships() {
        Map<String, Set<String>> expected = new Map<String, Set<String>>{
            '12345678901' => new Set<String>{ '12345678904', '12345678905' },
            '12345678902' => new Set<String>{ '12345678904', '12345678905' },
            '12345678903' => new Set<String>{ '12345678904' },
            '12345678904' => new Set<String>(),
            '12345678905' => new Set<String>()
        };
        List<User> viewers = [
            SELECT Id, AccountId, Account.INT_PersonIdent__c
            FROM User
            WHERE IsPortalEnabled = TRUE AND Account.INT_PersonIdent__c IN :expected.keySet()
        ];
        Assert.areEqual(5, viewers.size());
        Test.startTest();
        for (User viewer : viewers) {
            System.runAs(viewer) {
                Set<String> expectedChildren = expected.get(viewer.Account.INT_PersonIdent__c);
                Assert.areEqual(
                    2,
                    [SELECT COUNT() FROM Account WHERE INT_PersonIdent__c IN ('12345678904', '12345678905')],
                    'Record visibility alone must not grant fixture responsibility'
                );
                List<stoPersonContext.PersonOption> result = stoPersonContext.getRepresentableChildren();
                Set<String> actualChildren = new Set<String>();
                for (stoPersonContext.PersonOption child : result) {
                    actualChildren.add(child.representedPersonIdentifier);
                }
                Assert.areEqual(expectedChildren, actualChildren, 'Follow the README family for each signed-in person');
                for (String childIdent : new List<String>{ '12345678904', '12345678905' }) {
                    Assert.areEqual(
                        expectedChildren.contains(childIdent),
                        stoPersonContext.verifyRepresentation(childIdent),
                        'Verification and dropdown options must use the same family relationships'
                    );
                }
                Assert.areEqual(viewer.AccountId, stoPersonContext.resolveAccountId(null), 'Self remains accessible');
            }
        }
        Assert.areEqual(0, Limits.getCallouts());
        Test.stopTest();
    }

    @IsTest
    static void readsSharedThreadsAndRejectsForeignInbox() {
        User reader = viewer();
        Test.startTest();
        Thread__c thread = new Thread__c(CRM_Account__c = reader.AccountId, CRM_IsActive__c = true);
        insert thread;
        thread.CRM_Thread_Type__c = 'STO';
        thread.STO_Category__c = 'Arbeid';
        update thread;
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Fixture inbox message',
            CRM_Type__c = 'Message',
            CRM_Read__c = false
        );
        System.runAs(reader) {
            Assert.areEqual(
                0,
                ((List<Object>) stoInboxHelper.getAccessibleInboxPage(null, null, null).get('recent')).size(),
                'The adapter must not bypass missing record shares.'
            );
        }
        insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = reader.Id, AccessLevel = 'Read');
        System.runAs(reader) {
            Map<String, Object> page = stoInboxHelper.getAccessibleInboxPage(null, null, null);
            List<Object> recent = (List<Object>) page.get('recent');
            Assert.areEqual(1, recent.size());
            Map<String, Object> item = (Map<String, Object>) recent[0];
            Assert.areEqual(thread.Id, item.get('recordId'));
            Assert.areEqual('Arbeid', item.get('category'));
            Assert.areEqual(
                'Fixture inbox message',
                ((Map<String, Object>) item.get('latestmessage')).get('messageText')
            );
            try {
                stoInboxHelper.getAccessibleInboxPage(UserInfo.getUserId(), null, null);
                Assert.fail('A non-authorized Account must not be accepted.');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void notePaginationAndCursorValidation() {
        User reader = viewer();
        Id accountId = reader.AccountId;
        List<Conversation_Note__c> notes = new List<Conversation_Note__c>();
        Assert.areEqual(50, stoScratchFixtures.PAGE_SIZE);
        stoScratchFixtures.PAGE_SIZE = 2;
        for (Integer i = 0; i < 3; i++) {
            notes.add(
                new Conversation_Note__c(
                    CRM_Account__c = accountId,
                    CRM_Is_Read__c = false,
                    CRM_Created_By_Ident__c = 'Z999999',
                    CRM_Conversation_Note__c = 'Fixture note ' + i
                )
            );
        }
        insert notes;
        List<Conversation_Note__Share> shares = new List<Conversation_Note__Share>();
        for (Conversation_Note__c note : notes) {
            shares.add(
                new Conversation_Note__Share(ParentId = note.Id, UserOrGroupId = reader.Id, AccessLevel = 'Read')
            );
        }
        insert shares;
        System.runAs(reader) {
            Map<String, Object> first = stoScratchFixtures.inbox(accountId, null, null);
            Assert.areEqual(2, ((List<Object>) first.get('recent')).size());
            Assert.areEqual(true, first.get('hasMore'));
            Map<String, Object> second = stoScratchFixtures.inbox(accountId, null, (Id) first.get('beforeNoteId'));
            Assert.areEqual(1, ((List<Object>) second.get('recent')).size());
            Assert.areEqual(false, second.get('hasMore'));
            Set<Id> ids = new Set<Id>();
            for (Object value : (List<Object>) first.get('recent')) {
                ids.add((Id) ((Map<String, Object>) value).get('recordId'));
            }
            Assert.isFalse(
                ids.contains((Id) ((Map<String, Object>) ((List<Object>) second.get('recent'))[0]).get('recordId'))
            );
            try {
                stoScratchFixtures.inbox(null, null, notes[0].Id);
                Assert.fail('A cursor from another Account must be rejected.');
            } catch (AuraHandledException expected) {
                Assert.isNotNull(expected);
            }
        }
    }
}

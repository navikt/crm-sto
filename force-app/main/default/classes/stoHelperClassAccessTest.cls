@IsTest
private with sharing class stoHelperClassAccessTest {
    private static final String PARENT_IDENT = '12345678901';
    private static final String OTHER_PARENT_IDENT = '12345678902';
    private static final String CHILD_IDENT = '12345678904';

    @TestSetup
    static void setup() {
        Profile communityProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'STO Test Community Login Profile' AND UserType = 'PowerCustomerSuccess'
            LIMIT 1
        ];
        UserRole ownerRole = new UserRole(Name = 'STO access ' + STO_TestDataFactory.generateRandomString(8));
        insert ownerRole;
        User owner = (User) STO_TestDataFactory.createRecord(
            new User(
                ProfileId = UserInfo.getProfileId(),
                UserRoleId = ownerRole.Id,
                TimeZoneSidKey = UserInfo.getTimeZone().getID()
            )
        );
        System.runAs(owner) {
            STO_TestDataFactory.createRecordList(
                new List<SObject>{
                    person(PARENT_IDENT, 'Parent', 35),
                    person(OTHER_PARENT_IDENT, 'Other parent', 36),
                    person(CHILD_IDENT, 'Child', 8)
                }
            );
            List<User> readers = new List<User>();
            for (Account subject : [
                SELECT Id, PersonContactId, LastName
                FROM Account
                WHERE CRM_Person__r.Name IN :new Set<String>{ PARENT_IDENT, OTHER_PARENT_IDENT, CHILD_IDENT }
            ]) {
                readers.add(
                    new User(
                        Username = 'sto.access.' + UserInfo.getOrganizationId() + '.' + subject.Id + '@example.test',
                        Email = 'reader@example.test',
                        LastName = subject.LastName,
                        Alias = 'stoacc',
                        CommunityNickname = 'sto-access-' + subject.Id,
                        ProfileId = communityProfile.Id,
                        ContactId = subject.PersonContactId,
                        TimeZoneSidKey = owner.TimeZoneSidKey,
                        LocaleSidKey = 'no_NO',
                        EmailEncodingKey = 'UTF-8',
                        LanguageLocaleKey = 'no'
                    )
                );
            }
            System.runAs(new User(Id = owner.Id)) {
                insert readers;
                Id experienceAccess = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Experience' LIMIT 1].Id;
                List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
                for (User reader : readers) {
                    assignments.add(
                        new PermissionSetAssignment(AssigneeId = reader.Id, PermissionSetId = experienceAccess)
                    );
                }
                insert assignments;
            }
            List<AccountShare> accountShares = new List<AccountShare>();
            for (Account subject : [
                SELECT Id, PersonContactId
                FROM Account
                WHERE CRM_Person__r.Name IN :new Set<String>{ PARENT_IDENT, OTHER_PARENT_IDENT, CHILD_IDENT }
            ]) {
                for (User reader : readers) {
                    if (reader.ContactId != subject.PersonContactId) {
                        accountShares.add(
                            new AccountShare(
                                AccountId = subject.Id,
                                UserOrGroupId = reader.Id,
                                AccountAccessLevel = 'Read',
                                OpportunityAccessLevel = 'None',
                                CaseAccessLevel = 'None'
                            )
                        );
                    }
                }
            }
            insert accountShares;
        }
    }

    private static Person__c person(String ident, String name, Integer age) {
        return new Person__c(
            Name = ident,
            INT_FirstName__c = name,
            INT_LastName__c = name,
            INT_Confidential__c = 'UGRADERT',
            INT_DateOfBirth__c = String.valueOf(Date.today().addYears(-age))
        );
    }

    private static Account subject(String ident) {
        return [
            SELECT Id, Name, PersonContactId
            FROM Account
            WHERE CRM_Person__r.Name = :ident
            LIMIT 1
        ];
    }

    private static User reader(String ident) {
        Id contactId = subject(ident).PersonContactId;
        return [SELECT Id, ContactId FROM User WHERE ContactId = :contactId LIMIT 1];
    }

    private static Thread__c newThread(Account subject, String threadType) {
        Id recordTypeId = Thread__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('NKS_Thread')
            .getRecordTypeId();
        Thread__c thread = new Thread__c(
            CRM_Account__c = subject.Id,
            CRM_Contact__c = subject.PersonContactId,
            Name = threadType == 'BTO' ? 'Beskjed til oss' : 'Skriv til oss',
            CRM_Thread_Type__c = threadType,
            STO_Category__c = 'Familie',
            STO_Medskriv__c = true,
            RecordTypeId = recordTypeId
        );
        insert as system thread;
        return thread;
    }

    private static Thread__c sharedThread(User starter, String threadType) {
        Thread__c thread = newThread(subject(CHILD_IDENT), threadType);
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Type__c = 'Message',
            CRM_Message_Text__c = 'Original message',
            CRM_From_Contact__c = starter.ContactId,
            CRM_Sent_date__c = System.now().addDays(-1)
        );
        List<Thread__Share> shares = new List<Thread__Share>();
        for (String ident : new List<String>{ PARENT_IDENT, OTHER_PARENT_IDENT, CHILD_IDENT }) {
            shares.add(new Thread__Share(ParentId = thread.Id, UserOrGroupId = reader(ident).Id, AccessLevel = 'Edit'));
        }
        insert shares;
        return thread;
    }

    private static void assertCannotMutate(User viewer, Id threadId) {
        System.runAs(viewer) {
            Assert.isFalse(stoReplyContext.getReplyContext(threadId).canReply);
            Integer beforeCount = [SELECT COUNT() FROM Message__c WHERE CRM_Thread__c = :threadId];
            try {
                CRM_MessageHelperExperience.createThreadMessage(threadId, 'Not the original sender');
                Assert.fail('The existing message endpoint must reject a different sender');
            } catch (AuraHandledException expected) {
                Assert.areEqual(beforeCount, [SELECT COUNT() FROM Message__c WHERE CRM_Thread__c = :threadId]);
            }
            try {
                stoHelperClass.closeThread(threadId);
                Assert.fail('The existing close endpoint must report the rejected closure');
            } catch (AuraHandledException expected) {
                Assert.isTrue([SELECT CRM_isActive__c FROM Thread__c WHERE Id = :threadId].CRM_isActive__c);
            }
            Database.SaveResult messageResult = Database.insert(
                new Message__c(
                    CRM_Thread__c = threadId,
                    CRM_Message_Text__c = 'Direct write attempt',
                    CRM_From_Contact__c = viewer.ContactId
                ),
                false,
                AccessLevel.SYSTEM_MODE
            );
            Assert.isFalse(messageResult.isSuccess(), 'Legacy Edit shares must not bypass message authorization');
            Assert.isTrue(messageResult.getErrors()[0].getMessage().contains(stoReplyContext.READ_ONLY_MESSAGE));
            for (
                Thread__c closure : new List<Thread__c>{
                    new Thread__c(Id = threadId, CRM_isActive__c = false),
                    new Thread__c(Id = threadId, CRM_Closed_Date__c = Date.today())
                }
            ) {
                Database.SaveResult closeResult = Database.update(closure, false, AccessLevel.SYSTEM_MODE);
                Assert.isFalse(closeResult.isSuccess(), 'Both ways of closing a thread must enforce the same rule');
                Assert.isTrue(closeResult.getErrors()[0].getMessage().contains(stoReplyContext.READ_ONLY_MESSAGE));
            }
            CRM_MessageHelperExperience.markAsRead(threadId);
        }
    }

    @IsTest
    static void parentStarterCanReplyAndClose() {
        User parent = reader(PARENT_IDENT);
        Thread__c thread = sharedThread(parent, 'STO');
        String childName = subject(CHILD_IDENT).Name;
        Test.startTest();
        System.runAs(parent) {
            stoReplyContext context = stoReplyContext.getReplyContext(thread.Id);
            Assert.isTrue(context.canReply);
            Assert.isTrue(context.isWritingForChild);
            Assert.isTrue(context.wasStartedOnBehalfOfOwner);
            Assert.isNull(context.inboxSenderLabel);
            Assert.areEqual('Gjelder: ' + childName + ' (8 år)', context.representedLabel);
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Parent follow-up'));
            stoHelperClass.closeThread(thread.Id);
            Assert.isFalse([SELECT CRM_isActive__c FROM Thread__c WHERE Id = :thread.Id].CRM_isActive__c);
        }
        Test.stopTest();
    }

    @IsTest
    static void childAndOtherParentCannotReplyOrClose() {
        User parent = reader(PARENT_IDENT);
        User otherParent = reader(OTHER_PARENT_IDENT);
        User child = reader(CHILD_IDENT);
        Thread__c thread = sharedThread(parent, 'STO');
        String parentName = subject(PARENT_IDENT).Name;
        String childName = subject(CHILD_IDENT).Name;
        Test.startTest();
        assertCannotMutate(child, thread.Id);
        assertCannotMutate(otherParent, thread.Id);
        System.runAs(child) {
            stoReplyContext context = stoReplyContext.getReplyContext(thread.Id);
            Assert.isNull(context.representedLabel, 'A child must not see a banner representing themselves');
            Assert.isFalse(context.isWritingForChild);
            Assert.isTrue(context.wasStartedOnBehalfOfOwner);
            Assert.areEqual(parentName + ' startet samtalen', context.inboxSenderLabel);
        }
        System.runAs(otherParent) {
            stoReplyContext context = stoReplyContext.getReplyContext(thread.Id);
            Assert.areEqual(parentName + ' på vegne av ' + childName, context.representedLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void childStarterCanReplyButParentCannot() {
        User child = reader(CHILD_IDENT);
        User parent = reader(PARENT_IDENT);
        Thread__c thread = sharedThread(child, 'BTO');
        Test.startTest();
        assertCannotMutate(parent, thread.Id);
        System.runAs(child) {
            stoReplyContext context = stoReplyContext.getReplyContext(thread.Id);
            Assert.isTrue(context.canReply);
            Assert.isFalse(context.wasStartedOnBehalfOfOwner);
            Assert.isNull(context.representedLabel);
            Assert.isNull(context.inboxSenderLabel);
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Child follow-up'));
            stoHelperClass.closeThread(thread.Id);
        }
        Test.stopTest();
    }

    @IsTest
    static void firstMessageUsesThreadCreatorBeforeAnyMessageExists() {
        User parent = reader(PARENT_IDENT);
        Account child = subject(CHILD_IDENT);
        Test.startTest();
        System.runAs(parent) {
            Thread__c thread = newThread(child, 'STO');
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'First message for child'));
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
        }
        Test.stopTest();
    }

    @IsTest
    static void existingSelfSubmissionEndpointKeepsWorking() {
        User child = reader(CHILD_IDENT);
        Test.startTest();
        System.runAs(child) {
            Thread__c thread = stoHelperClass.createThreadWithCaseV2(
                'Familie',
                'Self submission',
                true,
                'STO',
                'Skriv til oss',
                'Familie',
                false
            );
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
            Assert.areEqual(
                child.ContactId,
                [SELECT CRM_From_Contact__c FROM Message__c WHERE CRM_Thread__c = :thread.Id LIMIT 1]
                .CRM_From_Contact__c
            );
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Follow-up'));
            stoHelperClass.closeThread(thread.Id);
        }
        Test.stopTest();
    }

    @IsTest
    static void senderShareUsesEditAndSkipsExistingOwner() {
        Account child = subject(CHILD_IDENT);
        Thread__c thread = newThread(child, 'STO');
        Test.startTest();
        STO_ThreadService.grantSubmitterAccess(thread.Id);
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Thread__Share WHERE ParentId = :thread.Id AND RowCause = 'Manual'],
            'The owner already has access'
        );
        Id differentOwner = [SELECT OwnerId FROM Account WHERE Id = :child.Id].OwnerId;
        update new Thread__c(Id = thread.Id, OwnerId = differentOwner);
        STO_ThreadService.grantSubmitterAccess(thread.Id);
        Assert.areEqual(
            'Edit',
            [
                SELECT AccessLevel
                FROM Thread__Share
                WHERE ParentId = :thread.Id AND UserOrGroupId = :UserInfo.getUserId() AND RowCause = 'Manual'
            ]
            .AccessLevel
        );
        Test.stopTest();
    }

    @IsTest
    static void legacySelfThreadAndInternalAgentKeepAccess() {
        User child = reader(CHILD_IDENT);
        Thread__c thread = newThread(subject(CHILD_IDENT), 'STO');
        insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = child.Id, AccessLevel = 'Edit');
        Test.startTest();
        System.runAs(child) {
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
            Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Legacy self reply'));
        }
        Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
        Assert.isTrue(CRM_MessageHelperExperience.createThreadMessage(thread.Id, 'Internal reply'));
        stoHelperClass.closeThread(thread.Id);
        Test.stopTest();
    }

    @IsTest
    static void missingOriginalSenderDoesNotGrantOwnerAccess() {
        User child = reader(CHILD_IDENT);
        Thread__c thread = newThread(subject(CHILD_IDENT), 'STO');
        insert new Thread__Share(ParentId = thread.Id, UserOrGroupId = child.Id, AccessLevel = 'Edit');
        Message__c original = new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Imported original message without a contact',
            CRM_External_Message__c = true,
            CRM_Sent_date__c = System.now().addDays(-2)
        );
        insert as system original;
        // Emulate legacy data after the message trigger has derived its external status.
        original.CRM_External_Message__c = true;
        update as system original;
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Later message is not the original sender',
            CRM_From_Contact__c = child.ContactId
        );
        Test.startTest();
        assertCannotMutate(child, thread.Id);
        Assert.areEqual('', stoReplyContext.getReplyRecipientFirstName(thread.Id));
        Test.stopTest();
    }

    @IsTest
    static void inboxLabelsUseOriginalSenderAndCurrentViewer() {
        User parent = reader(PARENT_IDENT);
        User child = reader(CHILD_IDENT);
        Thread__c thread = sharedThread(parent, 'STO');
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Later message',
            CRM_From_Contact__c = reader(OTHER_PARENT_IDENT).ContactId
        );
        String senderName = subject(PARENT_IDENT).Name;
        Test.startTest();
        System.runAs(child) {
            Assert.areEqual(
                senderName + ' startet samtalen',
                stoReplyContext.inboxSenderLabels(new Set<Id>{ thread.Id }).get(thread.Id)
            );
        }
        System.runAs(parent) {
            Assert.isNull(stoReplyContext.inboxSenderLabels(new Set<Id>{ thread.Id }).get(thread.Id));
        }
        Assert.areEqual(0, stoReplyContext.inboxSenderLabels(new Set<Id>()).size());
        Test.stopTest();
    }

    @IsTest
    static void getReplyContextRejectsMissingThread() {
        Test.startTest();
        try {
            stoReplyContext.getReplyContext(null);
            Assert.fail('A missing thread must not grant reply or close access.');
        } catch (AuraHandledException error) {
            Assert.areEqual('Vi kunne ikke hente samtalen.', error.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void recipientRejectsMissingThread() {
        Test.startTest();
        try {
            stoReplyContext.getReplyRecipientFirstName(null);
            Assert.fail('A missing thread must not return an unverified recipient.');
        } catch (AuraHandledException error) {
            Assert.areEqual('Vi kunne ikke hente samtalen.', error.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void recipientIsOriginalParentNotChildOrLatestSender() {
        User parent = reader(PARENT_IDENT);
        Thread__c thread = sharedThread(parent, 'STO');
        insert new Message__c(
            CRM_Thread__c = thread.Id,
            CRM_Message_Text__c = 'Later imported message',
            CRM_From_Contact__c = reader(OTHER_PARENT_IDENT).ContactId
        );
        String expected = [SELECT FirstName FROM Contact WHERE Id = :parent.ContactId].FirstName;
        Test.startTest();
        Assert.areEqual(expected, stoReplyContext.getReplyRecipientFirstName(thread.Id));
        System.runAs(parent) {
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
        }
        Test.stopTest();
    }

    @IsTest
    static void inaccessibleThreadDoesNotExposeContextOrRecipient() {
        Thread__c thread = newThread(subject(CHILD_IDENT), 'STO');
        User otherParent = reader(OTHER_PARENT_IDENT);
        Test.startTest();
        System.runAs(otherParent) {
            Assert.areEqual(0, [SELECT COUNT() FROM Thread__c WHERE Id = :thread.Id], 'The fixture must be private');
            Assert.areEqual(0, stoReplyContext.inboxSenderLabels(new Set<Id>{ thread.Id }).size());
            try {
                stoReplyContext.getReplyContext(thread.Id);
                Assert.fail('The reply-context endpoint must not disclose an inaccessible thread');
            } catch (AuraHandledException expected) {
                Assert.areEqual('Vi kunne ikke hente samtalen.', expected.getMessage());
            }
            try {
                stoReplyContext.getReplyRecipientFirstName(thread.Id);
                Assert.fail('The reply-context endpoint must not disclose an inaccessible recipient');
            } catch (AuraHandledException expected) {
                Assert.areEqual('Vi kunne ikke hente samtalen.', expected.getMessage());
            }
            try {
                STO_RecordInfoController.getRelatedRecord(String.valueOf(thread.Id), 'CRM_Contact__c', 'Thread__c');
                Assert.fail('A hidden record must not disclose its related contact');
            } catch (AuraHandledException expected) {
                Assert.areEqual('Vi kunne ikke hente posten.', expected.getMessage());
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void bulkChecksCoverAllStoTypesWithoutBlockingReadUpdates() {
        User parent = reader(PARENT_IDENT);
        User otherParent = reader(OTHER_PARENT_IDENT);
        List<Message__c> messages = new List<Message__c>();
        List<Thread__c> closures = new List<Thread__c>();
        for (String threadType : new List<String>{ 'STO', 'STB', 'BTO' }) {
            Thread__c thread = sharedThread(parent, threadType);
            messages.add(new Message__c(CRM_Thread__c = thread.Id, CRM_Message_Text__c = 'Blocked bulk reply'));
            closures.add(new Thread__c(Id = thread.Id, CRM_isActive__c = false));
        }
        Test.startTest();
        System.runAs(otherParent) {
            for (Database.SaveResult result : Database.insert(messages, false, AccessLevel.SYSTEM_MODE)) {
                Assert.isFalse(result.isSuccess());
                Assert.isTrue(result.getErrors()[0].getMessage().contains(stoReplyContext.READ_ONLY_MESSAGE));
            }
            for (Database.SaveResult result : Database.update(closures, false, AccessLevel.SYSTEM_MODE)) {
                Assert.isFalse(result.isSuccess());
                Assert.isTrue(result.getErrors()[0].getMessage().contains(stoReplyContext.READ_ONLY_MESSAGE));
            }
            Id threadId = closures[0].Id;
            Message__c readUpdate = [SELECT Id FROM Message__c WHERE CRM_Thread__c = :threadId LIMIT 1];
            readUpdate.CRM_Read__c = true;
            update readUpdate;
        }
        Test.stopTest();
    }

    @IsTest
    static void senderChecksHaveABoundedQueryBudgetForTwoHundredRecords() {
        User parent = reader(PARENT_IDENT);
        User otherParent = reader(OTHER_PARENT_IDENT);
        Thread__c thread = sharedThread(parent, 'STO');
        List<Message__c> messages = new List<Message__c>();
        List<Thread__c> closures = new List<Thread__c>();
        Map<Id, SObject> previous = new Map<Id, SObject>();
        for (Integer index = 0; index < 200; index++) {
            String suffix = '000000000000' + index;
            Id threadId = index == 0 ? thread.Id : Id.valueOf(String.valueOf(thread.Id).left(3) + suffix.right(12));
            messages.add(new Message__c(CRM_Thread__c = threadId, CRM_Message_Text__c = 'Rejected reply'));
            closures.add(new Thread__c(Id = threadId, CRM_Thread_Type__c = 'STO', CRM_isActive__c = false));
            previous.put(threadId, new Thread__c(Id = threadId, CRM_isActive__c = true));
        }
        Test.startTest();
        System.runAs(otherParent) {
            Integer beforeMessages = Limits.getQueries();
            stoReplyContext.checkMessages(messages);
            Assert.isTrue(
                Limits.getQueries() - beforeMessages <= 2,
                'The batch may query the actor once and all thread contexts once, never once per message'
            );
            for (Message__c message : messages) {
                Assert.isTrue(message.hasErrors());
            }
            Integer beforeClosures = Limits.getQueries();
            stoReplyContext.checkClosures(closures, previous);
            Assert.isTrue(
                Limits.getQueries() - beforeClosures <= 1,
                'Closure checks must reuse the actor and query all thread contexts once'
            );
            for (Thread__c closure : closures) {
                Assert.isTrue(closure.hasErrors());
            }
            Integer beforeLabels = Limits.getQueries();
            Map<Id, String> labels = stoReplyContext.inboxSenderLabels(previous.keySet());
            Assert.isTrue(Limits.getQueries() - beforeLabels <= 1, 'Sender labels must use one bulk thread query');
            Assert.areEqual(new Set<Id>{ thread.Id }, labels.keySet(), 'Missing threads must not produce sender data');
        }
        Test.stopTest();
    }

    @IsTest
    static void emptySenderLabelsDoNotQueryAndThreadContextsStayFresh() {
        User parent = reader(PARENT_IDENT);
        Account child = subject(CHILD_IDENT);
        Test.startTest();
        System.runAs(parent) {
            Integer beforeEmpty = Limits.getQueries();
            Assert.isTrue(stoReplyContext.inboxSenderLabels(new Set<Id>()).isEmpty());
            Assert.areEqual(beforeEmpty, Limits.getQueries());
            Thread__c thread = newThread(child, 'STO');
            Assert.isTrue(stoReplyContext.getReplyContext(thread.Id).canReply);
            insert as system new Message__c(
                CRM_Thread__c = thread.Id,
                CRM_Message_Text__c = 'An imported original from the child',
                CRM_From_Contact__c = child.PersonContactId
            );
            Assert.isFalse(
                stoReplyContext.getReplyContext(thread.Id).canReply,
                'A cached creator fallback must not override an original message inserted later'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void replyContextPreservesTheWirePayload() {
        stoReplyContext context = new stoReplyContext();
        context.canReply = true;
        context.senderName = 'Sender';
        context.representedName = 'Child';
        context.representedLabel = 'Gjelder: Child';
        context.inboxSenderLabel = 'Sender startet samtalen';
        context.isWritingForChild = true;
        context.wasStartedOnBehalfOfOwner = true;
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(context));
        Assert.areEqual(
            new Set<String>{
                'canReply',
                'senderName',
                'representedName',
                'representedLabel',
                'inboxSenderLabel',
                'isWritingForChild',
                'wasStartedOnBehalfOfOwner'
            },
            payload.keySet(),
            'Moving the DTO must preserve its wire fields without exposing internal query data'
        );
        Assert.areEqual(true, payload.get('canReply'));
        Assert.areEqual('Child', payload.get('representedName'));
    }
}

// TODO(backend-ready): KEEP ownership/access regressions and isolated test selections; REPLACE scratch integration fixtures only.
@IsTest
private class stoPersonContextTest {
    @TestSetup
    static void setup() {
        // TODO(backend-ready): REPLACE synthetic identity dependencies in integration tests with approved provider fixtures.
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678904'));
        STO_TestDataFactory.createRecord(new Person__c(Name = '12345678901'));
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Kontakt NAV', CRM_Code__c = 'KNA', CRM_Code_Set__c = 'Tema')
        );
        STO_TestDataFactory.createRecord(
            new Common_Code__c(Name = 'Sporsmal og Svar', CRM_Code__c = 'SPM_OG_SVR', CRM_Code_Set__c = 'Oppgavetyper')
        );
    }

    private static Account child() {
        return [SELECT Id, Name, PersonContactId FROM Account WHERE INT_PersonIdent__c = '12345678904' LIMIT 1];
    }

    @IsTest
    static void ownershipAndInbox() {
        Account child = child();
        stoPersonContext.testChildren = new List<Account>{ child };
        Assert.areEqual(child.Id, stoPersonContext.getRepresentableChildren()[0].value);
        Assert.areEqual(child.Name, stoPersonContext.getRepresentableChildren()[0].label);
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
        Assert.areEqual(thread.Id, stoInboxHelper.getThreadsForPerson(child.Id)[0].recordId);
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
            PermissionSet fixturePermission = new PermissionSet(Name = 'OwnershipFixture', Label = 'Ownership fixture');
            insert fixturePermission;
            insert new FieldPermissions(
                ParentId = fixturePermission.Id,
                SObjectType = 'Account',
                Field = 'Account.INT_PersonIdent__c',
                PermissionsRead = true
            );
            insert new SetupEntityAccess(
                ParentId = fixturePermission.Id,
                SetupEntityId = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'STO_Scratch_Family']
                .Id
            );
            insert new PermissionSetAssignment(AssigneeId = parentUser.Id, PermissionSetId = fixturePermission.Id);
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
        stoPersonContext.testChildren = new List<Account>{ child };
        Thread__c thread;
        System.runAs(parentUser) {
            // TODO(backend-ready): Exercise the entire real parent provider, including citizen-visible queries and opt-in.
            stoPersonContext.testChildren = null;
            Assert.isTrue(FeatureManagement.checkPermission('STO_Scratch_Family'));
            List<stoPersonContext.PersonOption> actualSelections = stoPersonContext.getRepresentableChildren();
            if (URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
                Assert.areEqual(1, actualSelections.size());
                Assert.areEqual(child.Id, actualSelections[0].value);
            } else {
                Assert.areEqual(0, actualSelections.size(), 'Fixtures must not authorize outside a scratch org');
                stoPersonContext.testChildren = new List<Account>{ child };
            }
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
}

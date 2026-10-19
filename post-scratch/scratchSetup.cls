//Add default admin user to the chat queue and grant chat access and adds default role for community user creation
User usr = [SELECT Id FROM User WHERE Name = 'User User'];
usr.UserRoleId = [SELECT Id FROM UserRole WHERE Name = 'NKS' LIMIT 1]?.Id;
usr.CRM_NAV_Ident__c = 'Z999999'; //Setting default nav ident for the scratch user
update usr;

// TODO(backend-ready): KEEP scratch user/license setup while demo logins are used; REMOVE family entries only when retiring fixtures.
// PersonHandler creates the Person Accounts when dummy-data/data/persons.json is imported.
Set<String> personIdents = new Set<String>{ '12345678901', '12345678904', '12345678905' };
List<Account> personAccounts = [
    SELECT FirstName, LastName, PersonContactId, INT_PersonIdent__c
    FROM Account
    WHERE INT_PersonIdent__c IN :personIdents AND IsPersonAccount = TRUE
];
System.assertEquals(3, personAccounts.size(), 'Import all three test persons from dummy-data/data/persons.json first.');
Set<Id> contactIds = new Set<Id>();
for (Account personAccount : personAccounts) {
    System.assertNotEquals(null, personAccount.PersonContactId, 'The test Person Account must have a contact.');
    contactIds.add(personAccount.PersonContactId);
}

Map<Id, User> usersByContact = new Map<Id, User>();
for (User communityUser : [SELECT Id, ContactId, IsActive FROM User WHERE ContactId IN :contactIds]) {
    System.assert(communityUser.IsActive, 'The existing test community user must be active: ' + communityUser.Id);
    usersByContact.put(communityUser.ContactId, communityUser);
}

Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'Scratch Community Profile' LIMIT 1];
// Scratch orgs have only one member-based Plus license; use login-based licenses for the children.
Profile childPortalProfile = [
    SELECT Id
    FROM Profile
    WHERE Name = 'Scratch Community Login Profile'
    LIMIT 1
];
List<User> usersToInsert = new List<User>();
for (Account personAccount : personAccounts) {
    if (usersByContact.containsKey(personAccount.PersonContactId)) {
        continue;
    }
    String userName = personAccount.FirstName + '.' + personAccount.LastName + '@' + URL.getOrgDomainUrl().getHost();
    usersToInsert.add(
        new User(
            UserName = userName,
            FirstName = personAccount.FirstName,
            LastName = personAccount.LastName,
            Alias = personAccount.FirstName.left(8),
            Email = userName,
            ContactId = personAccount.PersonContactId,
            ProfileId = personAccount.INT_PersonIdent__c == '12345678901' ? portalProfile.Id : childPortalProfile.Id,
            EmailEncodingKey = 'UTF-8',
            CommunityNickname = 'test' + personAccount.INT_PersonIdent__c,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US'
        )
    );
}
insert usersToInsert;
for (User communityUser : usersToInsert) {
    usersByContact.put(communityUser.ContactId, communityUser);
}

Set<Id> userIds = new Set<Id>();
for (User communityUser : usersByContact.values()) {
    userIds.add(communityUser.Id);
}
PermissionSet permSet = [SELECT Id FROM PermissionSet WHERE Name = 'STO_experience'];
Set<Id> assignedUserIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :permSet.Id AND AssigneeId IN :userIds
]) {
    assignedUserIds.add(assignment.AssigneeId);
}
List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
for (Id userId : userIds) {
    if (!assignedUserIds.contains(userId)) {
        assignmentsToInsert.add(new PermissionSetAssignment(PermissionSetId = permSet.Id, AssigneeId = userId));
    }
}
insert assignmentsToInsert;

// TODO(backend-ready): REMOVE this synthetic family AccountShare setup when retiring fixtures.
// REPLACE production relationship access/revocation with the approved backend lifecycle, not this script.
// This script already opts the synthetic parent into Scratch Community Profile.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family fixtures require a scratch org.'
);
User parentUser;
List<Account> childAccounts = new List<Account>();
for (Account personAccount : personAccounts) {
    if (personAccount.INT_PersonIdent__c == '12345678901') {
        parentUser = usersByContact.get(personAccount.PersonContactId);
    } else {
        childAccounts.add(personAccount);
    }
}
Set<Id> sharedAccountIds = new Set<Id>();
for (AccountShare existingShare : [
    SELECT AccountId
    FROM AccountShare
    WHERE UserOrGroupId = :parentUser.Id AND AccountId IN :childAccounts
]) {
    sharedAccountIds.add(existingShare.AccountId);
}
List<AccountShare> familyShares = new List<AccountShare>();
for (Account childAccount : childAccounts) {
    if (!sharedAccountIds.contains(childAccount.Id)) {
        familyShares.add(
            new AccountShare(
                AccountId = childAccount.Id,
                UserOrGroupId = parentUser.Id,
                AccountAccessLevel = 'Edit',
                OpportunityAccessLevel = 'None',
                CaseAccessLevel = 'None',
                RowCause = Schema.AccountShare.RowCause.Manual
            )
        );
    }
}
insert familyShares;

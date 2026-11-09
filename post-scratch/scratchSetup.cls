// Creates/reuses the synthetic family's separate community logins and ordinary inbox permissions.
// Scratch needs these actors to test parent/child perspectives; production user provisioning is not replaced.
// Setup-record DML stays separate from the fixture record-sharing transaction.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family fixtures require a scratch org.'
);
// PersonHandler creates the Person Accounts when dummy-data/data/persons.json is imported.
User usr = [SELECT Id FROM User WHERE Name = 'User User'];
usr.UserRoleId = [SELECT Id FROM UserRole WHERE Name = 'NKS' LIMIT 1]?.Id;
usr.CRM_NAV_Ident__c = 'Z999999';
update usr;

// Fixture roster only; responsibility lookup and authorization belong to the backend.
StaticResource fixture = [SELECT Body FROM StaticResource WHERE Name = 'STO_Foreldreansvar_Family' LIMIT 1];
Map<String, List<String>> family = (Map<String, List<String>>) JSON.deserialize(
    fixture.Body.toString(),
    Map<String, List<String>>.class
);
Set<String> personIdents = new Set<String>(family.keySet());
for (List<String> children : family.values()) {
    personIdents.addAll(children);
}
List<Account> personAccounts = [
    SELECT FirstName, LastName, PersonContactId, INT_PersonIdent__c
    FROM Account
    WHERE INT_PersonIdent__c IN :personIdents AND IsPersonAccount = TRUE
];
System.assertEquals(5, personAccounts.size(), 'Import all five test persons from dummy-data/data/persons.json first.');
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
// Scratch orgs have one member-based Plus license; use login-based licenses for everyone except Far.
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
Set<String> permissionNames = new Set<String>{ 'STO_Experience', 'STO_Scratch_Fixtures' };
List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name IN :permissionNames];
System.assertEquals(permissionNames.size(), permSets.size(), 'Deploy the scratch fixture permission set first.');
Set<Id> permissionIds = new Map<Id, PermissionSet>(permSets).keySet();
Set<String> existingAssignments = new Set<String>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId, PermissionSetId
    FROM PermissionSetAssignment
    WHERE PermissionSetId IN :permissionIds AND AssigneeId IN :userIds
]) {
    existingAssignments.add(assignment.AssigneeId + ':' + assignment.PermissionSetId);
}
List<PermissionSetAssignment> assignmentsToInsert = new List<PermissionSetAssignment>();
for (Id userId : userIds) {
    for (PermissionSet permSet : permSets) {
        if (!existingAssignments.contains(userId + ':' + permSet.Id)) {
            assignmentsToInsert.add(new PermissionSetAssignment(PermissionSetId = permSet.Id, AssigneeId = userId));
        }
    }
}
insert assignmentsToInsert;

// ToDo(backend): Extend STO_Experience with read-state class access and the necessary read-only Person/identity fields.
// ToDo(backend): Supply barn()/verifiser() responses for the synthetic family through the backend integration, not a local provider.
// Run scratchFamilySharing.cls in a separate transaction after this script to avoid mixed setup/record DML.

//Add default admin user to the chat queue and grant chat access and adds default role for community user creation
User usr = [SELECT Id FROM User WHERE Name = 'User User'];
usr.UserRoleId = [SELECT Id FROM UserRole WHERE Name = 'NKS' LIMIT 1]?.Id;
usr.CRM_NAV_Ident__c = 'Z999999'; //Setting default nav ident for the scratch user
update usr;

// TODO(backend-ready): KEEP scratch user/license setup while demo logins are used; REMOVE family entries only when retiring fixtures.
// PersonHandler creates the Person Accounts when dummy-data/data/persons.json is imported.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family fixtures require a scratch org.'
);
Map<String, Set<String>> family = stoPersonContext.scratchFamily();
Set<String> personIdents = new Set<String>(family.keySet());
for (Set<String> children : family.values()) {
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

// TODO(backend-ready): REMOVE explicit fixture grants with the scratch provider; children never receive this permission.
Set<Id> parentUserIds = new Set<Id>();
for (Account personAccount : personAccounts) {
    if (family.containsKey(personAccount.INT_PersonIdent__c)) {
        parentUserIds.add(usersByContact.get(personAccount.PersonContactId).Id);
    }
}
Id familyPermissionId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Scratch_Family' LIMIT 1].Id;
Set<Id> optedInParents = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :familyPermissionId AND AssigneeId IN :parentUserIds
]) {
    optedInParents.add(assignment.AssigneeId);
}
List<PermissionSetAssignment> familyAssignments = new List<PermissionSetAssignment>();
for (Id parentUserId : parentUserIds) {
    if (!optedInParents.contains(parentUserId)) {
        familyAssignments.add(new PermissionSetAssignment(PermissionSetId = familyPermissionId, AssigneeId = parentUserId));
    }
}
insert familyAssignments;

// Read-only field/object access for the viewer's narrowly shared Person__c label details.
Id labelPermissionId = [SELECT Id FROM PermissionSet WHERE Name = 'STO_Thread_Representation_Label' LIMIT 1].Id;
Set<Id> labelAssignedUserIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :labelPermissionId AND AssigneeId IN :userIds
]) {
    labelAssignedUserIds.add(assignment.AssigneeId);
}
List<PermissionSetAssignment> labelAssignments = new List<PermissionSetAssignment>();
for (Id userId : userIds) {
    if (!labelAssignedUserIds.contains(userId)) {
        labelAssignments.add(new PermissionSetAssignment(PermissionSetId = labelPermissionId, AssigneeId = userId));
    }
}
insert labelAssignments;
// Run scratchFamilySharing.cls in a separate transaction after this script to avoid mixed setup/record DML.

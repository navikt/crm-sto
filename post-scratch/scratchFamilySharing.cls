// Gives only the synthetic family initial Account/Person Read access that imported records lack.
// This is a fixture prerequisite, not parental authorization or conversation sharing.
// Keep separate from scratchSetup.cls: User/PermissionSetAssignment and record shares cannot share a transaction.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family fixtures require a scratch org.'
);
// These fixture relationships provision Account/Person access only, never production authorization.
StaticResource fixture = [SELECT Body FROM StaticResource WHERE Name = 'STO_Foreldreansvar_Family' LIMIT 1];
Map<String, List<String>> family = (Map<String, List<String>>) JSON.deserialize(
    fixture.Body.toString(),
    Map<String, List<String>>.class
);
Set<String> personIdents = new Set<String>(family.keySet());
for (List<String> children : family.values()) {
    personIdents.addAll(children);
}
Map<String, Account> accountsByIdent = new Map<String, Account>();
Set<Id> contactIds = new Set<Id>();
Set<Id> accountIds = new Set<Id>();
for (Account personAccount : [
    SELECT Id, PersonContactId, INT_PersonIdent__c, CRM_Person__c
    FROM Account
    WHERE INT_PersonIdent__c IN :personIdents AND IsPersonAccount = TRUE
]) {
    accountsByIdent.put(personAccount.INT_PersonIdent__c, personAccount);
    contactIds.add(personAccount.PersonContactId);
    accountIds.add(personAccount.Id);
}
System.assertEquals(5, accountsByIdent.size(), 'Import all five test persons before family sharing.');
Map<Id, User> usersByContact = new Map<Id, User>();
for (User communityUser : [
    SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds AND IsActive = TRUE
]) {
    usersByContact.put(communityUser.ContactId, communityUser);
}
Set<Id> parentUserIds = new Set<Id>();
for (String parentIdent : family.keySet()) {
    User parent = usersByContact.get(accountsByIdent.get(parentIdent).PersonContactId);
    System.assertNotEquals(null, parent, 'Run scratchSetup.cls first to provision every parent login.');
    parentUserIds.add(parent.Id);
}
Set<Id> labelViewerUserIds = new Set<Id>(parentUserIds);
for (String childIdent : new Set<String>{ '12345678904', '12345678905' }) {
    User child = usersByContact.get(accountsByIdent.get(childIdent).PersonContactId);
    System.assertNotEquals(null, child, 'Run scratchSetup.cls first to provision every child login.');
    labelViewerUserIds.add(child.Id);
}

Set<String> existingFamilyShares = new Set<String>();
for (AccountShare existingShare : [
    SELECT AccountId, UserOrGroupId
    FROM AccountShare
    WHERE UserOrGroupId IN :parentUserIds AND AccountId IN :accountIds
]) {
    existingFamilyShares.add(existingShare.UserOrGroupId + ':' + existingShare.AccountId);
}
List<AccountShare> familyShares = new List<AccountShare>();
for (String parentIdent : family.keySet()) {
    Id parentUserId = usersByContact.get(accountsByIdent.get(parentIdent).PersonContactId).Id;
    for (String childIdent : family.get(parentIdent)) {
        Id childAccountId = accountsByIdent.get(childIdent).Id;
        if (!existingFamilyShares.contains(parentUserId + ':' + childAccountId)) {
            familyShares.add(
                new AccountShare(
                    AccountId = childAccountId,
                    UserOrGroupId = parentUserId,
                    AccountAccessLevel = 'Read',
                    OpportunityAccessLevel = 'None',
                    CaseAccessLevel = 'None',
                    RowCause = Schema.AccountShare.RowCause.Manual
                )
            );
        }
    }
}
insert familyShares;

// Account sharing alone does not expose Person identity, birth date and confidentiality.
Set<String> existingPersonShares = new Set<String>();
for (Person__Share existingShare : [
    SELECT ParentId, UserOrGroupId
    FROM Person__Share
    WHERE UserOrGroupId IN :labelViewerUserIds
]) {
    existingPersonShares.add(existingShare.UserOrGroupId + ':' + existingShare.ParentId);
}
List<Person__Share> personShares = new List<Person__Share>();
for (String parentIdent : family.keySet()) {
    Id parentUserId = usersByContact.get(accountsByIdent.get(parentIdent).PersonContactId).Id;
    for (String childIdent : family.get(parentIdent)) {
        Id personId = accountsByIdent.get(childIdent).CRM_Person__c;
        System.assertNotEquals(null, personId, 'The test child must have a Person record.');
        if (!existingPersonShares.contains(parentUserId + ':' + personId)) {
            personShares.add(
                new Person__Share(
                    ParentId = personId,
                    UserOrGroupId = parentUserId,
                    AccessLevel = 'Read',
                    RowCause = Schema.Person__Share.RowCause.Manual
                )
            );
        }
    }
}
for (String childIdent : personIdents) {
    Id childUserId = usersByContact.get(accountsByIdent.get(childIdent).PersonContactId).Id;
    Id childPersonId = accountsByIdent.get(childIdent).CRM_Person__c;
    if (!existingPersonShares.contains(childUserId + ':' + childPersonId)) {
        personShares.add(
            new Person__Share(
                ParentId = childPersonId,
                UserOrGroupId = childUserId,
                AccessLevel = 'Read',
                RowCause = Schema.Person__Share.RowCause.Manual
            )
        );
    }
}
insert personShares;

// ToDo(backend): getAccessibleInboxPage/getAccessibleOpenThreadsForPerson must authorize and share threads and conversation notes.
// ToDo(backend): Handle new/closed conversations, subject/sender access and revocation through real backend functions, not fixture maps.
System.debug(LoggingLevel.INFO, 'Family fixture Account/Person shares added: ' + familyShares.size() + '/' + personShares.size());

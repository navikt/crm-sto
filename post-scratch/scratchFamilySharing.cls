// TODO(backend-ready): REMOVE synthetic family shares with the scratch provider.
// Keep separate from scratchSetup.cls: User/PermissionSetAssignment and record shares cannot share a transaction.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family fixtures require a scratch org.'
);
Map<String, Set<String>> family = stoPersonContext.scratchFamily();
Set<String> personIdents = new Set<String>(family.keySet());
for (Set<String> children : family.values()) {
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
    labelViewerUserIds.add(usersByContact.get(accountsByIdent.get(childIdent).PersonContactId).Id);
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
                    AccountAccessLevel = 'Edit',
                    OpportunityAccessLevel = 'None',
                    CaseAccessLevel = 'None',
                    RowCause = Schema.AccountShare.RowCause.Manual
                )
            );
        }
    }
}
insert familyShares;

// Account sharing alone does not expose the Person lookup needed for birth date/confidentiality.
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
for (String childIdent : new Set<String>{ '12345678904', '12345678905' }) {
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

// Existing child-owned conversations need the same read-only family access as newly created ones.
Set<Id> eligibleChildAccountIds = new Set<Id>();
Set<String> childIdents = new Set<String>();
for (Set<String> children : family.values()) {
    childIdents.addAll(children);
}
String adultBirthDate = String.valueOf(Date.today().addYears(-18));
String today = String.valueOf(Date.today());
for (Account child : [
    SELECT Id FROM Account
    WHERE INT_PersonIdent__c IN :childIdents AND IsPersonAccount = TRUE
        AND CRM_Person__r.INT_Confidential__c = 'UGRADERT'
        AND CRM_Person__r.INT_DateOfBirth__c > :adultBirthDate
        AND CRM_Person__r.INT_DateOfBirth__c <= :today
]) {
    eligibleChildAccountIds.add(child.Id);
}
Set<Id> optedInParentUserIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId FROM PermissionSetAssignment
    WHERE AssigneeId IN :parentUserIds AND PermissionSet.Name = 'STO_Scratch_Family'
]) {
    optedInParentUserIds.add(assignment.AssigneeId);
}
List<Thread__c> childThreads = [
    SELECT Id, CRM_Account__c FROM Thread__c
    WHERE CRM_Account__c IN :eligibleChildAccountIds AND CRM_Thread_Type__c IN ('STO', 'STB', 'BTO')
];
Set<Id> threadIds = new Map<Id, Thread__c>(childThreads).keySet();
Set<String> existingThreadShares = new Set<String>();
for (Thread__Share share : [
    SELECT ParentId, UserOrGroupId FROM Thread__Share
    WHERE ParentId IN :threadIds AND UserOrGroupId IN :parentUserIds
]) {
    existingThreadShares.add(share.ParentId + ':' + share.UserOrGroupId);
}
List<Thread__Share> threadShares = new List<Thread__Share>();
for (Thread__c childThread : childThreads) {
    for (String parentIdent : family.keySet()) {
        Id parentUserId = usersByContact.get(accountsByIdent.get(parentIdent).PersonContactId).Id;
        if (!optedInParentUserIds.contains(parentUserId)) {
            continue;
        }
        for (String childIdent : family.get(parentIdent)) {
            if (accountsByIdent.get(childIdent).Id == childThread.CRM_Account__c &&
                !existingThreadShares.contains(childThread.Id + ':' + parentUserId)) {
                threadShares.add(new Thread__Share(
                    ParentId = childThread.Id, UserOrGroupId = parentUserId,
                    AccessLevel = 'Read', RowCause = Schema.Thread__Share.RowCause.Manual
                ));
            }
        }
    }
}
insert threadShares;
System.debug(LoggingLevel.INFO, 'Family thread Read shares added: ' + threadShares.size());

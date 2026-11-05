// Provision Read shares for the synthetic accounts only; runtime inbox queries still run with sharing.
System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Inbox fixtures require a scratch org.'
);
StaticResource fixture = [SELECT Body FROM StaticResource WHERE Name = 'STO_Foreldreansvar_Family' LIMIT 1];
Map<String, List<String>> family = (Map<String, List<String>>) JSON.deserialize(
    fixture.Body.toString(), Map<String, List<String>>.class
);
Set<String> identities = new Set<String>(family.keySet());
for (List<String> children : family.values()) {
    identities.addAll(children);
}
Map<String, Account> accounts = new Map<String, Account>();
Set<Id> contactIds = new Set<Id>();
for (Account record : [
    SELECT Id, PersonContactId, INT_PersonIdent__c
    FROM Account WHERE IsPersonAccount = TRUE AND INT_PersonIdent__c IN :identities
]) {
    accounts.put(record.INT_PersonIdent__c, record);
    contactIds.add(record.PersonContactId);
}
System.assertEquals(5, accounts.size(), 'Import all five synthetic people first.');
Map<Id, Id> usersByContact = new Map<Id, Id>();
for (User record : [SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds AND IsActive = TRUE]) {
    usersByContact.put(record.ContactId, record.Id);
}
System.assertEquals(5, usersByContact.size(), 'Run scratchSetup.cls first.');
Map<Id, Set<Id>> readersByAccount = new Map<Id, Set<Id>>();
for (Account record : accounts.values()) {
    readersByAccount.put(record.Id, new Set<Id>{ usersByContact.get(record.PersonContactId) });
}
for (String parentIdent : family.keySet()) {
    Id reader = usersByContact.get(accounts.get(parentIdent).PersonContactId);
    for (String childIdent : family.get(parentIdent)) {
        readersByAccount.get(accounts.get(childIdent).Id).add(reader);
    }
}
Set<Id> accountIds = readersByAccount.keySet();
Set<Id> readerIds = new Set<Id>(usersByContact.values());
List<SObject> records = new List<SObject>();
records.addAll([SELECT Id, OwnerId, CRM_Account__c FROM Thread__c WHERE CRM_Account__c IN :accountIds]);
records.addAll([SELECT Id, OwnerId, CRM_Account__c FROM Conversation_Note__c WHERE CRM_Account__c IN :accountIds]);
Set<Id> recordIds = new Map<Id, SObject>(records).keySet();
Set<String> existing = new Set<String>();
for (Thread__Share share : [
    SELECT ParentId, UserOrGroupId FROM Thread__Share WHERE ParentId IN :recordIds AND UserOrGroupId IN :readerIds
]) {
    existing.add(share.ParentId + ':' + share.UserOrGroupId);
}
for (Conversation_Note__Share share : [
    SELECT ParentId, UserOrGroupId FROM Conversation_Note__Share
    WHERE ParentId IN :recordIds AND UserOrGroupId IN :readerIds
]) {
    existing.add(share.ParentId + ':' + share.UserOrGroupId);
}
List<SObject> shares = new List<SObject>();
for (SObject record : records) {
    for (Id reader : readersByAccount.get((Id) record.get('CRM_Account__c'))) {
        if (reader == record.get('OwnerId') || existing.contains(record.Id + ':' + reader)) {
            continue;
        }
        String shareType = record instanceof Thread__c ? 'Thread__Share' : 'Conversation_Note__Share';
        SObject share = Schema.getGlobalDescribe().get(shareType).newSObject();
        share.put('ParentId', record.Id);
        share.put('UserOrGroupId', reader);
        share.put('AccessLevel', 'Read');
        share.put('RowCause', 'Manual');
        shares.add(share);
    }
}
insert shares;
System.debug(LoggingLevel.INFO, 'Synthetic inbox Read shares added: ' + shares.size());

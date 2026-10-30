System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family mocks require a scratch org.'
);
Map<String, Set<String>> family = stoPersonContext.scratchFamily();
Set<String> personIdents = new Set<String>(family.keySet());
for (Set<String> children : family.values()) {
    personIdents.addAll(children);
}
Set<Id> contactIds = new Set<Id>();
for (Account person : [
    SELECT PersonContactId
    FROM Account
    WHERE IsPersonAccount = TRUE AND INT_PersonIdent__c IN :personIdents
]) {
    contactIds.add(person.PersonContactId);
}
List<User> familyUsers = [SELECT Id FROM User WHERE ContactId IN :contactIds AND IsActive = TRUE];
System.assertEquals(
    personIdents.size(),
    familyUsers.size(),
    'Run scratchSetup.cls first to provision the test family.'
);
List<API_Controller_Mock_Settings__c> settings = new List<API_Controller_Mock_Settings__c>();
for (User familyUser : familyUsers) {
    API_Controller_Mock_Settings__c setting = API_Controller_Mock_Settings__c.getValues(familyUser.Id);
    if (setting == null) {
        setting = new API_Controller_Mock_Settings__c(SetupOwnerId = familyUser.Id);
    }
    setting.Status__c = 'OK';
    setting.Status_Code__c = '200';
    setting.Use_Mock__c = true;
    settings.add(setting);
}
upsert settings;

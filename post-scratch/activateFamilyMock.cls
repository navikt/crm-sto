System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Family mocks require a scratch org.'
);
Set<String> parentIdents = stoPersonContext.scratchFamily().keySet();
Set<Id> contactIds = new Set<Id>();
for (Account parent : [
    SELECT PersonContactId
    FROM Account
    WHERE IsPersonAccount = TRUE AND INT_PersonIdent__c IN :parentIdents
]) {
    contactIds.add(parent.PersonContactId);
}
List<User> parents = [SELECT Id FROM User WHERE ContactId IN :contactIds AND IsActive = TRUE];
System.assertEquals(3, parents.size(), 'Run scratchSetup.cls first to provision all three test parents.');
List<API_Controller_Mock_Settings__c> settings = new List<API_Controller_Mock_Settings__c>();
for (User parent : parents) {
    API_Controller_Mock_Settings__c setting = API_Controller_Mock_Settings__c.getValues(parent.Id);
    if (setting == null) {
        setting = new API_Controller_Mock_Settings__c(SetupOwnerId = parent.Id);
    }
    setting.Status__c = 'OK';
    setting.Status_Code__c = '200';
    setting.Use_Mock__c = true;
    settings.add(setting);
}
upsert settings;

// Optional legacy switch restoring real integration calls by disabling profile-level mock settings.
// User-level overrides are separate and are not cleared by this script.
for (Profile p : [SELECT Id FROM Profile]) {
    API_Controller_Mock_Settings__c mockSetting = API_Controller_Mock_Settings__c.getInstance(p.Id);
    mockSetting.Status__c = 'OK';
    mockSetting.Status_Code__c = '200';
    mockSetting.Use_Mock__c = false;
    upsert mockSetting;
}

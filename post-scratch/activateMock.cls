// Optional legacy switch for testing integrations with the existing profile-level mock mechanism.
// Applies to all profiles, supplies no response implementation and is not part of family setup.
for (Profile p : [SELECT Id FROM Profile]) {
    API_Controller_Mock_Settings__c mockSetting = API_Controller_Mock_Settings__c.getInstance(p.Id);
    mockSetting.Status__c = 'OK';
    mockSetting.Status_Code__c = '200';
    mockSetting.Use_Mock__c = true;
    upsert mockSetting;
}

//Dummy data script for creating community user and associated dummy data
Account communityAccount = [SELECT Id, FirstName, LastName, PersonContactId FROM Account WHERE CRM_Person__r.Name = '12345678901' LIMIT 1];

Profile portalProfile = [SELECT Id, Name FROM Profile WHERE UserType = 'PowerCustomerSuccess' and Name = 'Customer Community Plus User' LIMIT 1];


User portalUser = new User();
portalUser.FirstName = communityAccount.FirstName;
portalUser.LastName = communityAccount.LastName;
portalUser.ContactId = communityAccount.PersonContactId;
portalUser.Alias = 'hpott';
portalUser.Username = 'doktor.proktor@test.nav.henvendelse';
portalUser.Email = 'doktor.proktor@test.nav.henvendelse';
portalUser.ProfileId = portalProfile.Id;
portalUser.EmailEncodingKey = 'UTF-8';
portalUser.CommunityNickname = 'testUser1';
portalUser.TimeZoneSidKey = 'Europe/Paris';
portalUser.LocaleSidKey = 'no_NO';
portalUser.LanguageLocaleKey = 'no';
insert portalUser;

Case accCase = [SELECT Id, AccountId FROM Case LIMIT 1];
accCase.AccountId = communityAccount.Id;

//Create a dummy thread
Thread__c thread = new Thread__c();
thread.CRM_From__c = portalUser.Id;
thread.CRM_isActive__c = true;
thread.CRM_Related_Object__c = accCase.Id;
insert thread;

Message__c message = new Message__c(CRM_Thread__c = thread.Id,
                    CRM_Message_Text__c = 'Dette er en testmelding :)',
                    CRM_Read_Datetime__c = Datetime.now(),
                    CRM_Sent_Date__c = Datetime.now().addDays(-1));

insert message;

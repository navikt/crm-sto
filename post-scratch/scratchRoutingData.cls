System.assert(
    URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com'),
    'Utility routing fixtures require a scratch org.'
);
System.assertEquals(
    1,
    [SELECT COUNT() FROM AssignmentRule WHERE SobjectType = 'Case' AND Active = TRUE],
    'Deploy unpackaged/queues and unpackaged/assignmentRules first.'
);
Set<String> requiredQueues = new Set<String>{ 'STO_Familie', 'BTO_Helse' };
System.assertEquals(
    requiredQueues.size(),
    [SELECT COUNT() FROM Group WHERE Type = 'Queue' AND DeveloperName IN :requiredQueues],
    'The STO/BTO fixture queues are missing.'
);

Map<String, Set<String>> family = stoPersonContext.scratchFamily();
Set<String> personIdents = new Set<String>(family.keySet());
for (Set<String> children : family.values()) {
    personIdents.addAll(children);
}
Map<Id, Account> accounts = new Map<Id, Account>(
    [
        SELECT Id, PersonContactId, INT_PersonIdent__c
        FROM Account
        WHERE IsPersonAccount = TRUE AND INT_PersonIdent__c IN :personIdents
    ]
);
Account sender;
Set<Id> contactIds = new Set<Id>();
for (Account account : accounts.values()) {
    contactIds.add(account.PersonContactId);
    if (account.INT_PersonIdent__c == '12345678901') {
        sender = account;
    }
}
System.assertNotEquals(null, sender, 'Import the synthetic family persons before setting up utility data.');
Set<Id> communityUserIds = new Map<Id, User>(
        [SELECT Id FROM User WHERE ContactId IN :contactIds AND IsPortalEnabled = TRUE]
    )
    .keySet();

// Only recover unclaimed synthetic-family submissions, never an agent's work or completed cases.
List<Case> casesToRoute = [
    SELECT Id
    FROM Case
    WHERE
        RecordType.DeveloperName = 'STO_Case'
        AND Status = 'New'
        AND Origin IN ('STO', 'BTO')
        AND AccountId IN :accounts.keySet()
        AND OwnerId IN :communityUserIds
];
Database.DMLOptions options = new Database.DMLOptions();
options.optAllOrNone = true;
options.assignmentRuleHeader.useDefaultRule = true;
if (!casesToRoute.isEmpty()) {
    Database.update(casesToRoute, options);
}

Id caseRecordTypeId = Case.SObjectType.getDescribe()
    .getRecordTypeInfosByDeveloperName()
    .get('STO_Case')
    .getRecordTypeId();
Id threadRecordTypeId = Thread__c.SObjectType.getDescribe()
    .getRecordTypeInfosByDeveloperName()
    .get('NKS_Thread')
    .getRecordTypeId();
Map<String, String> categories = new Map<String, String>{ 'STO' => 'Familie', 'BTO' => 'Helse' };
Set<String> fixtureNames = new Set<String>{ 'Scratch utility STO - Familie', 'Scratch utility BTO - Helse' };
Set<String> existingFixtures = new Set<String>();
for (Thread__c thread : [SELECT Name FROM Thread__c WHERE Name IN :fixtureNames AND CRM_Account__c = :sender.Id]) {
    existingFixtures.add(thread.Name);
}
for (String origin : categories.keySet()) {
    String fixtureName = 'Scratch utility ' + origin + ' - ' + categories.get(origin);
    if (existingFixtures.contains(fixtureName)) {
        continue;
    }
    Case fixture = new Case(
        Subject = fixtureName,
        Description = 'Synthetic scratch data for the Skriv til oss utility.',
        RecordTypeId = caseRecordTypeId,
        AccountId = sender.Id,
        ContactId = sender.PersonContactId,
        Status = 'New',
        Origin = origin,
        STO_Category__c = categories.get(origin),
        CRM_Person_Confidentiality__c = 'UGRADERT',
        CRM_Person_Is_NAV_Employee__c = false
    );
    Database.insert(fixture, options);
    // The case is already created; set the thread type afterwards to avoid a second asynchronous case.
    Thread__c thread = new Thread__c(
        Name = fixtureName,
        RecordTypeId = threadRecordTypeId,
        CRM_Account__c = sender.Id,
        CRM_Contact__c = sender.PersonContactId,
        CRM_Related_Object__c = fixture.Id,
        CRM_isActive__c = true,
        STO_Category__c = categories.get(origin),
        NKS_Inbox_Title__c = origin == 'STO' ? 'Skriv til oss' : 'Beskjed til oss',
        NKS_Inbox_Theme__c = categories.get(origin)
    );
    insert thread;
    thread.CRM_Thread_Type__c = origin;
    update thread;
    insert new Message__c(
        CRM_Thread__c = thread.Id,
        CRM_From_Contact__c = sender.PersonContactId,
        CRM_Message_Text__c = 'Dette er en syntetisk testmelding for Skriv til oss.',
        CRM_Sent_Date__c = System.now()
    );
    existingFixtures.add(fixtureName);
}
System.assertEquals(2, existingFixtures.size(), 'Both STO and BTO utility fixtures must exist.');
System.debug('Scratch utility fixtures ready. Existing submissions re-routed: ' + casesToRoute.size());

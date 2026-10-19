// TODO(backend-ready): KEEP this scratch sample-data setup; REMOVE synthetic identities only when retiring demo data.
Account personAccount = [
    SELECT Id, PersonContactId
    FROM Account
    WHERE INT_PersonIdent__c = '12345678901' AND IsPersonAccount = TRUE AND CRM_Person__r.Name = '12345678901'
];
System.assertNotEquals(null, personAccount.PersonContactId, 'Doktor Proktor must have a Person Account contact.');
Contact personContact = [SELECT Id, AccountId FROM Contact WHERE Id = :personAccount.PersonContactId];

// TODO(backend-ready): KEEP account/contact linking for imported demo threads; never use this as a production migration.
// Tree imports cannot reference the Account and Contact created by PersonHandler in a different import.
Set<String> sampleThreadNames = new Set<String>{
    'Chat Arbeid',
    'Dialog med NAV - Uføretrygd',
    'Chat Familie',
    'Dialog med NAV - Arbeid'
};
List<Thread__c> importedThreads = [
    SELECT Id, CRM_Account__c, CRM_Contact__c
    FROM Thread__c
    WHERE
        CRM_External_Person_Ident__c = '12345678901'
        AND CRM_External_ActorId__c = '12345678910'
        AND Name IN :sampleThreadNames
        AND CRM_Account__c = NULL
];
for (Thread__c importedThread : importedThreads) {
    importedThread.CRM_Account__c = personAccount.Id;
    importedThread.CRM_Contact__c = personContact.Id;
}
update importedThreads;

// TODO(backend-ready): KEEP this deterministic demo case; REMOVE with the sample scenario, not with production ownership code.
Case accCase = new Case(
    Subject = 'TEST SUBJECT',
    Description = 'TEST DESCRIPTION',
    Origin = 'WEB',
    AccountId = personAccount.Id,
    ContactId = personContact.Id
);
insert accCase;

//Create a dummy thread
Thread__c thread = new Thread__c();
thread.CRM_Account__c = personContact.AccountId;
Thread.CRM_Contact__c = personContact.Id;
thread.CRM_isActive__c = true;
thread.CRM_Related_Object__c = accCase.Id;
insert thread;

Message__c message = new Message__c(CRM_Thread__c = thread.Id,
                    CRM_From_Contact__c = personContact.Id,
                    CRM_Message_Text__c = 'Dette er en testmelding :)',
                    CRM_Read_Datetime__c = Datetime.now(),
                    CRM_Sent_Date__c = Datetime.now().addDays(-1));

insert message;

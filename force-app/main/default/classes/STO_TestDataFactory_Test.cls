@isTest
private class STO_TestDataFactory_Test {
    
    @isTest
    static void testCreateCase() {
        // Create a test Account
        Account testAccount = new Account(LastName = 'TestAccount');
        insert testAccount;
        
        // Create a Case using the factory method
        Case testCase = STO_TestDataFactory.createCase('TestAccount');
        
        // Validate that the Case was created and linked to the correct Account
        Assert.areNotEqual(null, testCase.Id, 'Case should be created and have an Id');
        Assert.areEqual(testAccount.Id, testCase.AccountId, 'Case should be associated with the correct Account');
        Assert.areEqual('New', testCase.Status, 'Case should have the status "New"');
        Assert.areEqual('Web', testCase.Origin, 'Case should have the origin "Web"');
    }
    
    @isTest
    static void testCreatePersons() {
        // Create 3 Persons
        List<Person__c> persons = STO_TestDataFactory.createPersons(3);
        
        // Validate that the correct number of Persons were created
        Assert.areEqual(3, persons.size(), 'Three Person records should be created');
        
        // Validate that each Person has the correct fields populated
        for (Integer i = 0; i < persons.size(); i++) {
            Person__c person = persons[i];
            Assert.areEqual('1234567890' + i, person.Name, 'Person Name should be correctly populated');
            Assert.areEqual('0301', person.INT_MunicipalityNumber__c, 'Municipality Number should be correctly populated');
            Assert.areEqual('Test' + i, person.INT_LastName__c, 'Last Name should be correctly populated');
            Assert.areEqual('UGRADERT', person.INT_Confidential__c, 'Confidential field should be correctly populated');
            Assert.areEqual('UOPPGITT', person.INT_MaritalStatus__c, 'Marital Status should be correctly populated');
        }
    }
    
    @isTest
    static void testCreateLiveChatTranscripts() {
        // Create 5 LiveChatTranscripts
        List<LiveChatTranscript> transcripts = STO_TestDataFactory.createLiveChatTranscripts(5);
        
        // Validate that the correct number of LiveChatTranscripts were created
        Assert.areEqual(5, transcripts.size(), 'Five LiveChatTranscript records should be created');
        
        // Validate that each LiveChatTranscript is linked to a LiveChatVisitor
        for (LiveChatTranscript transcript : transcripts) {
           Assert.areNotEqual(null, transcript.Id, 'LiveChatTranscript should have an Id');
           Assert.areNotEqual(null, transcript.LiveChatVisitorId, 'LiveChatTranscript should be associated with a LiveChatVisitor');
        }
    }
    
    @isTest
    static void testCreateRecord() {
        // Test createRecord with an Account
        Account acc = new Account(Name = 'Test Account');
        Account insertedAcc = (Account) STO_TestDataFactory.createRecord(acc);
        
        // Validate that the Account was created
        Assert.areNotEqual(null, insertedAcc.Id, 'Account should be created and have an Id');
        Assert.areEqual('Test Account', insertedAcc.Name, 'Account should have the correct Name');
    }
    
    @isTest
    static void testCreateRecordList() {
        // Test creating a list of 3 Accounts
        Account acc = new Account(Name = 'Test Account');
        List<sObject> accounts = STO_TestDataFactory.createRecordList(acc, 3);
        
        // Validate that the correct number of Accounts were created
        Assert.areEqual(3, accounts.size(), 'Three Account records should be created');
        
        // Validate that each Account has the correct fields populated
        for (sObject obj : accounts) {
            Account account = (Account)obj;
            Assert.areNotEqual(null, account.Id, 'Account should be created and have an Id');
            Assert.areEqual('Test Account', account.Name, 'Account should have the correct Name');
        }
    }
}

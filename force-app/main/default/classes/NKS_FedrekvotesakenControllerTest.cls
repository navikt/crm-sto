@isTest
private class NKS_FedrekvotesakenControllerTest {
    @testSetup
    static void makeData() {
        Common_Code__c tema = new Common_Code__c(
            Name = 'Foreldre- og svangerskapspenger',
            CRM_Code_Set__c = 'Tema',
            CRM_Code__c = 'FOR'
        );
        Common_Code__c behandlingstema = new Common_Code__c(
            Name = 'Fedrekvote',
            CRM_Code_Set__c = 'Behandlingstema',
            CRM_Code__c = 'ab0342'
        );
        Common_Code__c temagruppe = new Common_Code__c(
            Name = 'Familie',
            CRM_Code_Set__c = 'Temagrupper',
            CRM_Code__c = 'FMLI'
        );
        insert tema;
        insert behandlingstema;
        insert temagruppe;

        Common_Code__c gjelder = new Common_Code__c(
            Name = 'Fedrekvote',
            CRM_Code_Set__c = 'Gjelder',
            CRM_Subtheme__c = behandlingstema.Id,
            CRM_Parent_Code__c = tema.Id,
            CRM_Code__c = 'FORTMab0342'
        );
        insert gjelder;

        NavUnit__c navUnit = new NavUnit__c(INT_UnitNumber__c = '4863', Name = 'test');
        insert navUnit;
    }

    @isTest
    static void testpostTask() {
        ApiMock.setTestMock('POST_CREATE_OPPGAVE', 201, 'Created');
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();
        String jsonData = JSON.serialize(fedrekvoteData);

        Test.startTest();
        NKS_FedrekvotesakenController.postTask(jsonData);
        Test.stopTest();

        List<Application_Log__c> logList = [
            SELECT Id
            FROM Application_Log__c
            WHERE Category__c = 'Fedrekvotesaken'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual(0, logList.size(), 'Application_Log__c record should not be created');
    }

    @isTest
    static void testFormatBeskrivelse() {
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();

        Test.startTest();
        String comment = NKS_FedrekvotesakenController.formatBeskrivelse(fedrekvoteData);
        Test.stopTest();

        Assert.areNotEqual(null, comment, 'Comment should not be null');
        Assert.areNotEqual('', comment, 'Comment should not be empty');
        Assert.areNotEqual(0, comment.length(), 'Comment should have > 0 length');
    }

    @isTest
    static void testHasExistingNavTasks() {
        ApiMock.setTestMock('GET_OPPGAVE', 200, 'OK');

        Test.startTest();
        Boolean hasTasks = NKS_FedrekvotesakenController.hasExistingNavTasks();
        Test.stopTest();

        Assert.areEqual(true, hasTasks, 'Expected one existing Oppgave in response');
    }

    private static NKS_FedrekvotesakenController.Fedrekvote makeTestData() {
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = new NKS_FedrekvotesakenController.Fedrekvote();
        fedrekvoteData.phone = '12345678';

        List<NKS_FedrekvotesakenController.Child> children = new List<NKS_FedrekvotesakenController.Child>();
        String childName = 'Johnny Bravo';
        String childBirthdate = '01-01-2000';

        for (String leaveType : new List<String>{ 'Yes', 'Partly', 'No' }) {
            NKS_FedrekvotesakenController.Child child = new NKS_FedrekvotesakenController.Child();
            child.name = childName;
            child.birthdate = childBirthdate;
            child.leave = new NKS_FedrekvotesakenController.Leave();
            child.leave.type = leaveType;
            child.leave.salary = 'Yes';
            if (leaveType == 'Partly' || leaveType == 'Yes') {
                child.leave.dates = new NKS_FedrekvotesakenController.Dates();
                child.leave.dates.fromDate = Date.today().addDays(-1).toString();
                child.leave.dates.toDate = Date.today().toString();
            }
            children.add(child);
        }

        fedrekvoteData.children = children;
        return fedrekvoteData;
    }

    @isTest
    static void testPostTaskThrowsOnFailedOppgave() {
        ApiMock.setTestMock('POST_CREATE_OPPGAVE', 500, 'Internal Server Error');
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();
        String jsonData = JSON.serialize(fedrekvoteData);

        Test.startTest();
        try {
            NKS_FedrekvotesakenController.postTask(jsonData);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();

        List<Application_Log__c> logList = [
            SELECT Id
            FROM Application_Log__c
            WHERE Category__c = 'Fedrekvotesaken'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual(1, logList.size(), 'An error log should have been created');
    }

    @isTest
    static void testPostTaskNullJson() {
        Test.startTest();
        NKS_FedrekvotesakenController.postTask('null');
        Test.stopTest();

        List<Application_Log__c> logList = [
            SELECT Id
            FROM Application_Log__c
            WHERE Category__c = 'Fedrekvotesaken'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual(1, logList.size(), 'An error log should have been created for null fedrekvoteData');
    }

    @isTest
    static void testHasExistingNavTasksThrowsOnFailure() {
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        Test.startTest();
        try {
            NKS_FedrekvotesakenController.hasExistingNavTasks();
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();

        List<Application_Log__c> logList = [
            SELECT Id
            FROM Application_Log__c
            WHERE Category__c = 'Fedrekvotesaken'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        Assert.areEqual(1, logList.size(), 'An error log should have been created');
    }

    @isTest
    static void testCreateSTBThreadDmlException() {
        ApiMock.setTestMock('POST_CREATE_OPPGAVE', 201, 'Created');
        NKS_FedrekvotesakenController.throwOnThreadInsert = true;
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();
        String jsonData = JSON.serialize(fedrekvoteData);

        Test.startTest();
        try {
            NKS_FedrekvotesakenController.postTask(jsonData);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateMessageDmlException() {
        ApiMock.setTestMock('POST_CREATE_OPPGAVE', 201, 'Created');
        NKS_FedrekvotesakenController.throwOnMessageInsert = true;
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();
        String jsonData = JSON.serialize(fedrekvoteData);

        Test.startTest();
        NKS_FedrekvotesakenController.postTask(jsonData);
        Test.stopTest();

        List<Message__c> messages = [SELECT Id FROM Message__c];
        Assert.areEqual(0, messages.size(), 'No message should have been inserted');
    }

    private class CalloutExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            CalloutException e = (CalloutException) CalloutException.class.newInstance();
            e.setMessage('Simulated callout exception');
            throw e;
        }
    }
}

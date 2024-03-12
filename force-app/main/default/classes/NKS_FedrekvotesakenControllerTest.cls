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
        insert tema;
        insert behandlingstema;

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
    static void testCreateNavTask() {
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();
        String jsonData = JSON.serialize(fedrekvoteData);

        Test.startTest();
        NKS_FedrekvotesakenController.createNavTask(jsonData);
        Test.stopTest();

        List<NavTask__c> navTasks = [SELECT Id FROM NavTask__c LIMIT 1];
        Assert.areNotEqual(0, navTasks.size(), 'NavTask record should be created');
    }

    @isTest
    static void testFormatComment() {
        NKS_FedrekvotesakenController.Fedrekvote fedrekvoteData = makeTestData();

        Test.startTest();
        String comment = NKS_FedrekvotesakenController.formatComment(fedrekvoteData);
        Test.stopTest();

        Assert.areNotEqual(null, comment, 'Comment should not be null');
        Assert.areNotEqual('', comment, 'Comment should not be empty');
        Assert.areNotEqual(0, comment.length(), 'Comment should have > 0 length');
    }

    @isTest
    static void testHasExistingNavTasks() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Test.startTest();
        Boolean hasTasks = NKS_FedrekvotesakenController.hasExistingNavTasks();
        Test.stopTest();

        Assert.areEqual(false, hasTasks, 'Expected zero existing NavTasks');
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
            if (leaveType == 'Partly') {
                child.leave.dates = new NKS_FedrekvotesakenController.Dates();
                child.leave.dates.fromDate = Date.today().addDays(-1).toString();
                child.leave.dates.toDate = Date.today().toString();
            }
            children.add(child);
        }

        fedrekvoteData.children = children;
        return fedrekvoteData;
    }
}

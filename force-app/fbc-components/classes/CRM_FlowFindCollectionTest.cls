@isTest
public with sharing class CRM_FlowFindCollectionTest {
    @isTest
    public static void CRM_FlowFindCollectionTest() {
        //create sample  data
        Account A = new Account(Name = 'test Account12345');
        insert A;

        CRM_FlowFindCollection.Requests request = new CRM_FlowFindCollection.Requests();
        request.sObjectName = 'Account';
        request.FieldApiINames = 'Name';
        request.WhereClause = 'Name = \'test Account12345\'';

        system.debug(request);

        List<CRM_FlowFindCollection.Requests> requests = new List<CRM_FlowFindCollection.Requests>{ request };

        Test.startTest();

        list<CRM_FlowFindCollection.Results> responses = CRM_FlowFindCollection.execute(requests);

        Test.stopTest();

        system.assertEquals(1, responses[0].outputCollection.size());

        //Todo - assertions around sharing access. Can NOT view
    }

    @isTest
    public static void CRM_FlowFindCollectionTest_WithoutSharing() {
        //create sample  data
        Account A = new Account(Name = 'test Account12345');
        insert A;

        CRM_FlowFindCollection.Requests request = new CRM_FlowFindCollection.Requests();
        request.sObjectName = 'Account';
        request.FieldApiINames = 'Name';
        request.WhereClause = 'Name = \'test Account12345\'';
        request.BypassSharing = true;
        List<CRM_FlowFindCollection.Requests> requests = new List<CRM_FlowFindCollection.Requests>{ request };

        //No sharing

        List<CRM_FlowFindCollection.Requests> requests2 = new List<CRM_FlowFindCollection.Requests>{ request };
        Test.startTest();
        list<CRM_FlowFindCollection.Results> responses_withoutsharing = CRM_FlowFindCollection.execute(requests2);
        Test.stopTest();

        //Todo - assertions around sharing access. Can still view
    }

    //Test IDS
}

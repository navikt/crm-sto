@IsTEst
public with sharing class relatedConversationNoteHelper_Test {
    @TestSetup
    static void produceRelatedNotes() {
        Conversation_Note__c con1 = new Conversation_Note__c(
            CRM_Created_By_Ident__c = 'Test1',
            CRM_Date_Time_Registered__c = DateTime.newInstance(2022, 5, 5, 12, 12, 12)
        );
        Conversation_Note__c con2 = new Conversation_Note__c(
            CRM_Created_By_Ident__c = 'Test2',
            CRM_Date_Time_Registered__c = DateTime.newInstance(2022, 6, 6, 12, 12, 12)
        );
        Conversation_Note__c con3 = new Conversation_Note__c(
            CRM_Created_By_Ident__c = 'Test3',
            CRM_Date_Time_Registered__c = DateTime.newInstance(2022, 6, 5, 12, 12, 12)
        );
        Conversation_Note__c con4 = new Conversation_Note__c(
            CRM_Created_By_Ident__c = 'Test4',
            CRM_Date_Time_Registered__c = DateTime.newInstance(2022, 7, 3, 12, 12, 12)
        );
        insert con1;
        insert con2;
        insert con3;
        insert con4;
    }

    @IsTest
    static void testgetRelatedConversationsParent() {
        Conversation_Note__c note = [
            SELECT Id, CRM_Henvendelse_BehandlingskjedeId__c, CRM_API_Reference__c
            FROM Conversation_Note__c
            WHERE CRM_Created_By_Ident__c = 'Test1'
        ][0];
        List<Conversation_Note__c> updateList = new List<Conversation_Note__c>();
        for (Conversation_Note__c child : [
            SELECT Id, CRM_Henvendelse_BehandlingskjedeId__c
            FROM Conversation_Note__c
            WHERE CRM_Created_By_Ident__c = 'Test2' OR CRM_Created_By_Ident__c = 'Test3'
            ORDER BY CRM_Date_Time_Registered__c DESC
        ]) {
            child.CRM_Henvendelse_BehandlingskjedeId__c = note.CRM_API_Reference__c;
            updateList.add(child);
        }
        update updateList;

        Test.startTest();
        List<Conversation_Note__c> res = relatedConversationNoteHelper.getRelatedConversations(
            note.CRM_Henvendelse_BehandlingskjedeId__c,
            null,
            note.CRM_API_Reference__c
        );
        Test.stopTest();
        System.assertEquals(2, res.size());
        System.assertEquals(updateList[0].Id, res[0].Id);
    }

    @isTest
    static void testgetRelatedConversationsChild() {
        Conversation_Note__c note = [
            SELECT Id, CRM_Henvendelse_BehandlingskjedeId__c, CRM_API_Reference__c
            FROM Conversation_Note__c
            WHERE CRM_Created_By_Ident__c = 'Test1'
        ][0];
        List<Conversation_Note__c> updateList = new List<Conversation_Note__c>();
        for (Conversation_Note__c child : [
            SELECT Id, CRM_Henvendelse_BehandlingskjedeId__c, CRM_API_Reference__c
            FROM Conversation_Note__c
            WHERE CRM_Created_By_Ident__c = 'Test2' OR CRM_Created_By_Ident__c = 'Test3'
            ORDER BY CRM_Date_Time_Registered__c DESC
        ]) {
            child.CRM_Henvendelse_BehandlingskjedeId__c = note.CRM_API_Reference__c;
            updateList.add(child);
        }
        update updateList;

        Test.startTest();
        List<Conversation_Note__c> res = relatedConversationNoteHelper.getRelatedConversations(
            updateList[0].CRM_Henvendelse_BehandlingskjedeId__c,
            null,
            updateList[0].CRM_API_Reference__c
        );
        Test.stopTest();
        System.assertEquals(1, res.size());
        System.assertEquals(note.Id, res[0].Id);
    }
}

@isTest
public class NKS_DialogueViewController_Test {
    @isTest
    static void testGetConvNotes() {
        //Create testdata
        Conversation_Note__c convNote = (Conversation_Note__c) STO_TestDataFactory.createRecord(
            new Conversation_Note__c()
        );
        Test.startTest();
        List<Conversation_Note__c> convNotes = NKS_DialogueViewController.getConvNote(convNote.Id);
        Test.stopTest();

        System.assert(convNotes.size() > 0, 'No conversation notes!');
    }

    @isTest
    static void testGetDialogueByApiReference() {
        //Create testdata
        Conversation_Note__c convNote = (Conversation_Note__c) STO_TestDataFactory.createRecord(
            new Conversation_Note__c()
        );

        Id[] fixedSearchResults = new Id[1];
        fixedSearchResults[0] = convNote.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        Test.startTest();
        String dialogue = NKS_DialogueViewController.getDialogueByApiReference('testference');
        Test.stopTest();

        System.assertNotEquals(null, dialogue);
    }

    @isTest
    static void testGetDialogueByApiReferenceException() {
        //Create testdata
        Conversation_Note__c convNote = (Conversation_Note__c) STO_TestDataFactory.createRecord(
            new Conversation_Note__c()
        );

        Test.startTest();
        try {
            String dialogue = NKS_DialogueViewController.getDialogueByApiReference('testference');
        } catch (AuraHandledException auraEx) {
            System.assert(true);
        }
        Test.stopTest();
    }
}

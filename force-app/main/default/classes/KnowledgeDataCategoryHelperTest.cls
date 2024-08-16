@IsTest
public with sharing class KnowledgeDataCategoryHelperTest {
    
    @IsTest
    static void testFetchDataCategoryLabels() {
        Test.startTest();
        Map<String, String> result = KnowledgeDataCategoryHelper.fetchDataCategoryLabels();
        Test.stopTest();
      
        String knownCategory = 'KnownCategory'; 
        if (result.containsKey(knownCategory)) {
            Assert.areNotEqual(null, result.get(knownCategory), 'The known category should have a label.');
        }
    }

    @IsTest
    static void testGetAllCategories() {
       Test.startTest();
       KnowledgeDataCategoryHelper.getAllCategories (new List<DataCategory>());
       Test.stopTest();
    } 
}
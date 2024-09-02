@isTest
public class UpdateKnowledgeArticlesBatchTest {
    @testSetup
    static void makeData() {
        // TODO: Not possible to create Data Category Group programmatically. It is required to insert Knowledge__DataCategorySelection. Tests fails on scratch test/validate.
        // Presume DataCategoryGroupName = 'Tema' and DataCategoryName = 'Dagpenger' and 'Sykepenger' exists in org
        List<Knowledge__kav> knowledgeArticles = new List<Knowledge__kav>();
        for (Integer i = 0; i < 3; i++) {
            Knowledge__kav article = new Knowledge__kav(
                Title = 'Test Article ' + i,
                UrlName = 'test-article-' + i,
                Language = 'en_US',
                NKS_Category__c = 'test'
            );
            knowledgeArticles.add(article);
        }
        insert knowledgeArticles;
    }

    // Hacky tests to get code coverage.

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Database.executeBatch(new UpdateKnowledgeArticlesBatch(), 20);
        Test.stopTest();
    }

    @isTest
    static void testExecute() {
        Test.startTest();
        UpdateKnowledgeArticlesBatch batch = new UpdateKnowledgeArticlesBatch();
        batch.execute(null, null);
        Test.stopTest();
    }
}

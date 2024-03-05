@isTest
public class UpdateKnowledgeArticlesBatchTest {
    @isTest
    static void testBatchExecution() {
        // Not possible to create Data Category Group programmatically? It is required to insert Knowledge__DataCategorySelection.
        // Presume DataCategoryGroupName = 'Tema' and DataCategoryName = 'Helse' exists in org
        List<Knowledge__kav> knowledgeArticles = new List<Knowledge__kav>();
        for (Integer i = 0; i < 3; i++) {
            Knowledge__kav article = new Knowledge__kav(
                Title = 'Test Article ' + i,
                UrlName = 'test-article-' + i,
                Language = 'en_US'
            );
            knowledgeArticles.add(article);
        }
        insert knowledgeArticles;

        List<Knowledge__DataCategorySelection> dataCategorySelections = new List<Knowledge__DataCategorySelection>();
        for (Knowledge__kav article : knowledgeArticles) {
            Knowledge__DataCategorySelection selection = new Knowledge__DataCategorySelection(
                ParentId = article.Id,
                DataCategoryName = 'Helse',
                DataCategoryGroupName = 'Tema'
            );
            dataCategorySelections.add(selection);
        }
        insert dataCategorySelections;

        Test.startTest();
        Database.executeBatch(new UpdateKnowledgeArticlesBatch(), 20);
        Test.stopTest();

        List<Knowledge__kav> updatedArticles = [
            SELECT Id, Title, NKS_Category__c
            FROM Knowledge__kav
            WHERE Id IN :knowledgeArticles
        ];

        System.assertEquals(3, updatedArticles.size(), 'Number of updated articles should match test data');
        for (Knowledge__kav article : updatedArticles) {
            Assert.areNotEqual(null, article.NKS_Category__c, 'NKS_Category__c should not be null');
        }
    }
}

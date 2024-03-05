public class UpdateKnowledgeArticlesBatch implements Database.Batchable<sObject> {
    private static Map<String, String> categoryLabelMap = KnowledgeDataCategoryHelper.fetchDataCategoryLabels();
    private String inputQuery;

    public UpdateKnowledgeArticlesBatch(String inputQuery) {
        this.inputQuery = inputQuery;
    }
    public UpdateKnowledgeArticlesBatch() {
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Get new Knowledge__DataCategorySelection records created the last 24 hours
        Datetime yesterday = Datetime.now().addDays(-1);
        String query = String.isNotBlank(inputQuery)
            ? inputQuery
            : 'SELECT ParentId, DataCategoryName FROM Knowledge__DataCategorySelection WHERE CreatedDate >= :yesterday AND Parent.IsLatestVersion = TRUE';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Knowledge__DataCategorySelection> scope) {
        // Get existing NKS_Category__c for each Article
        List<Knowledge__kav> articlesWithDataCategorySelections = [
            SELECT Id, NKS_Category__c
            FROM Knowledge__kav
            WHERE Id IN (SELECT ParentId FROM Knowledge__DataCategorySelection WHERE Id IN :scope)
        ];

        // Map to hold existing NKS_Category__c values for each article
        Map<Id, String> articleCategoryMap = new Map<Id, String>();
        for (Knowledge__kav article : articlesWithDataCategorySelections) {
            articleCategoryMap.put(article.Id, article.NKS_Category__c);
        }

        // Get new article categories found in scope
        Map<Id, List<String>> newArticleCategoriesMap = new Map<Id, List<String>>();
        for (Knowledge__DataCategorySelection selection : scope) {
            if (!newArticleCategoriesMap.containsKey(selection.ParentId)) {
                newArticleCategoriesMap.put(selection.ParentId, new List<String>());
            }
            String categoryName = categoryLabelMap.get(selection.DataCategoryName);
            newArticleCategoriesMap.get(selection.ParentId).add(categoryName);
        }

        // Update NKS_Category__c for each Article
        List<Knowledge__kav> articlesToUpdate = new List<Knowledge__kav>();
        for (Id articleId : newArticleCategoriesMap.keySet()) {
            String concatenatedCategories = articleCategoryMap.containsKey(articleId)
                ? articleCategoryMap.get(articleId) + ', ' + String.join(newArticleCategoriesMap.get(articleId), ', ')
                : String.join(newArticleCategoriesMap.get(articleId), ', ');

            Knowledge__kav article = new Knowledge__kav(Id = articleId);
            article.NKS_Category__c = concatenatedCategories.removeEnd(',').trim();
            articlesToUpdate.add(article);
        }

        if (!articlesToUpdate.isEmpty()) {
            update articlesToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) {
    }
}

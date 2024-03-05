public class UpdateKnowledgeArticlesBatch implements Database.Batchable<sObject> {
    private static Map<String, String> categoryLabelMap = KnowledgeDataCategoryHelper.fetchDataCategoryLabels();
    private String inputQuery;

    public UpdateKnowledgeArticlesBatch(String inputQuery) {
        this.inputQuery = inputQuery;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Get new Knowledge__DataCategorySelection records created the last 24 hours
        Datetime yesterday = Datetime.now().addDays(-1);
        String query = String.isNotBlank(inputQuery)
            ? inputQuery
            : 'SELECT Id, ParentId, DataCategoryName FROM Knowledge__DataCategorySelection WHERE CreatedDate >= :yesterday AND Parent.IsLatestVersion = TRUE';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Knowledge__DataCategorySelection> scope) {
        Map<Id, List<String>> articleCategoriesMap = new Map<Id, List<String>>();

        for (Knowledge__DataCategorySelection selection : scope) {
            if (!articleCategoriesMap.containsKey(selection.ParentId)) {
                articleCategoriesMap.put(selection.ParentId, new List<String>());
            }
            String categoryName = categoryLabelMap.get(selection.DataCategoryName);
            articleCategoriesMap.get(selection.ParentId).add(categoryName);
        }

        List<Knowledge__kav> articlesToUpdate = new List<Knowledge__kav>();
        for (Id articleId : articleCategoriesMap.keySet()) {
            String concatenatedCategories = String.join(articleCategoriesMap.get(articleId), ', ');

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

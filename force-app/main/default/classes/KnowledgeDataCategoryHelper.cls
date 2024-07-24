public without sharing class KnowledgeDataCategoryHelper {
    public static Map<String, String> fetchDataCategoryLabels() {
        Map<String, String> categoryLabels = new Map<String, String>();

        List<String> objType = new List<String>{ 'KnowledgeArticleVersion' };
        // Get data category groups for KnowledgeArticleVersion => ('Tema')
        List<DescribeDataCategoryGroupResult> describeCategoryResult = Schema.describeDataCategoryGroups(objType);
        List<DataCategoryGroupSobjectTypePair> pairs = new List<DataCategoryGroupSobjectTypePair>();

        for (DescribeDataCategoryGroupResult res : describeCategoryResult) {
            DataCategoryGroupSobjectTypePair p = new DataCategoryGroupSobjectTypePair();
            p.setSobject(res.getSobject());
            p.setDataCategoryGroupName(res.getName());
            pairs.add(p);
        }

        List<DescribeDataCategoryGroupStructureResult> describeCategoryStructureResult = Schema.describeDataCategoryGroupStructures(
            pairs,
            false
        );

        // Get all data categories under data category group
        for (DescribeDataCategoryGroupStructureResult structureRes : describeCategoryStructureResult) {
            List<DataCategory> allCategories = getAllCategories(structureRes.getTopCategories());
            for (DataCategory category : allCategories) {
                String key = category.getName();
                categoryLabels.put(key, category.getLabel());
            }
        }
        return categoryLabels;
    }

    private static List<DataCategory> getAllCategories(List<DataCategory> categories) {
        List<DataCategory> allCategories = new List<DataCategory>();
        for (DataCategory category : categories) {
            allCategories.add(category);
            allCategories.addAll(getAllCategories(category.getChildCategories()));
        }
        return allCategories;
    }
}

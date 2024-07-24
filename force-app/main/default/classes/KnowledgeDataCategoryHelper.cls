public without sharing class KnowledgeDataCategoryHelper {
    public static Map<String, String> fetchDataCategoryLabels() {
        return getCategoryLabelsForType('KnowledgeArticleVersion');
    }

    private static Map<String, String> getCategoryLabelsForType(String objectType) {
        // Get data category groups for KnowledgeArticleVersion => ('Tema')
        List<DescribeDataCategoryGroupResult> categoryGroupResults = Schema.describeDataCategoryGroups(
            new List<String>{ objectType }
        );
        Map<String, String> categoryLabelsByName = new Map<String, String>();
        List<DescribeDataCategoryGroupStructureResult> categoryStructureResults = getCategoryGroupStructures(
            categoryGroupResults
        );

        for (DescribeDataCategoryGroupStructureResult structureResult : categoryStructureResults) {
            categoryLabelsByName.putAll(getCategoryLabelsFromStructure(structureResult));
        }
        
        return categoryLabelsByName;
    }

    private static List<DescribeDataCategoryGroupStructureResult> getCategoryGroupStructures(
        List<DescribeDataCategoryGroupResult> categoryGroupResults
    ) {
        List<DataCategoryGroupSobjectTypePair> pairs = new List<DataCategoryGroupSobjectTypePair>();
        for (DescribeDataCategoryGroupResult groupResult : categoryGroupResults) {
            DataCategoryGroupSobjectTypePair pair = new DataCategoryGroupSobjectTypePair();
            pair.setSobject(groupResult.getSobject());
            pair.setDataCategoryGroupName(groupResult.getName());
            pairs.add(pair);
        }

        return Schema.describeDataCategoryGroupStructures(pairs, false);
    }

    private static Map<String, String> getCategoryLabelsFromStructure(
        DescribeDataCategoryGroupStructureResult structureResult
    ) {
        Map<String, String> categoryLabelsByName = new Map<String, String>();
        for (DataCategory category : getAllCategories(structureResult.getTopCategories())) {
            categoryLabelsByName.put(category.getName(), category.getLabel());
        }

        return categoryLabelsByName;
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

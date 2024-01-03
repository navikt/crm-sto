public with sharing class stoNewsController implements Metadata.DeployCallback {
    @AuraEnabled(cacheable=true)
    public static Map<String, List<STO_News__mdt>> getAllNews() {
        try {
            List<STO_Category__mdt> stoCategories = [
                SELECT STO_Category__c
                FROM STO_Category__mdt
            ];
            List<STO_News__mdt> stoNews = [
                SELECT Id, STO_Body__c, STO_Category__c, STO_Header__c, Developername
                FROM STO_News__mdt
            ];
            Map<String, List<STO_News__mdt>> retList = new Map<String, List<STO_News__mdt>>();
            for (STO_Category__mdt cat : stoCategories) {
                retList.put(cat.STO_Category__c, new List<STO_News__mdt>());
            }
            for (STO_News__mdt news : stoNews) {
                retList.get(news.STO_Category__c).add(news);
            }

            return retList;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateNews(String content, String title, String category, String developerName) {
        try {
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'STO_news.' + developerName; //custom metadata name
            customMetadata.label = developerName;

            Metadata.CustomMetadataValue customField1 = new Metadata.CustomMetadataValue(); //the values you're changing/updating
            customField1.field = 'STO_Body__c'; //the custom field API Name that you're wanting to insert/update a value of
            customField1.value = content;
            customMetadata.values.add(customField1);
            Metadata.CustomMetadataValue customField2 = new Metadata.CustomMetadataValue(); //the values you're changing/updating
            customField2.field = 'STO_Header__c'; //the custom field API Name that you're wanting to insert/update a value of
            customField2.value = title;
            customMetadata.values.add(customField2);
            Metadata.CustomMetadataValue customField3 = new Metadata.CustomMetadataValue(); //the values you're changing/updating
            customField3.field = 'STO_Category__c'; //the custom field API Name that you're wanting to insert/update a value of
            customField3.value = category;
            customMetadata.values.add(customField3);
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            // STO_News__mdt a = new STO_News__mdt(id=newsId, STO_Body__c = content, STO_Header__c = title, STO_Category__c = category)
            mdContainer.addMetadata(customMetadata);

            Metadata.Operations.enqueueDeployment(mdContainer, new stoNewsController());
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        LoggerUtility logger = new LoggerUtility();
        if (result.status == Metadata.DeployStatus.Succeeded) {
            logger.info('Fungerte, klarte å deploye metadata', null);
            // Deployment was successful
        } else {
            String msg =
                'Fungerte ikke, \nstatus: ' +
                result.status +
                '\ndetials: ' +
                result.details +
                '\nerror: ' +
                result.errorMessage;
            logger.error(msg, null);
            // Deployment was not successful
        }
        logger.publish();
    }
}

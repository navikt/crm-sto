public with sharing class UpdateCaseSubjectsBatch implements Database.Batchable<sObject> {
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            'SELECT STO_ExternalName__c, CRM_Case__c, CRM_Case__r.Subject FROM Thread__c WHERE CRM_Is_Closed__c = FALSE AND CRM_Thread_Type__c IN (\'STO\', \'BTO\') AND CRM_Case__c != NULL AND STO_ExternalName__c != NULL'
        );
    }
    public void execute(Database.BatchableContext BC, List<Thread__c> scope) {
        List<Case> casesToUpdate = new List<Case>();

        for (Thread__c threadRecord : scope) {
            Case caseToUpdate = new Case(Id = threadRecord.CRM_Case__c, Subject = threadRecord.STO_ExternalName__c);
            casesToUpdate.add(caseToUpdate);
        }

        if (!casesToUpdate.isEmpty()) {
            Database.update(casesToUpdate);
        }
    }
    public void finish(Database.BatchableContext BC) {
    }
}

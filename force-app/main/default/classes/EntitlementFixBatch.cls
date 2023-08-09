public with sharing class EntitlementFixBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(
            'Select Id, SlaProcessId from Entitlement where Name IN (\'BTO Entitlement\', \'STO Entitlement\') and SlaProcessId = null and AccountId NOT IN (Select AccountId from Case where Origin IN (\'STO\', \'BTO\') and Status NOT in (\'On Hold\', \'Closed\'))'
        );
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {
        SlaProcess slaProcess = [
            SELECT Id
            FROM SlaProcess
            WHERE IsActive = TRUE AND IsVersionDefault = TRUE AND name = 'sto_process'
            LIMIT 1
        ];
        List<Entitlement> entitlements = (List<Entitlement>) scope;
        for (Entitlement ent : entitlements) {
            ent.SlaProcessId = slaProcess.Id;
        }
        update entitlements;
    }

    public void finish(Database.BatchableContext BC) {
        System.scheduleBatch(new EntitlementFixBatch(), 'Fix broken STO entitlements', 3600);
    }
}

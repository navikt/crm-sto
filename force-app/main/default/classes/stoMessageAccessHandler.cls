global with sharing class stoMessageAccessHandler extends MyTriggers {
    global override void onBeforeInsert() {
        stoThreadAccess.checkMessages((List<Message__c>) records);
    }
}

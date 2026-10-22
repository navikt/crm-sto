global with sharing class stoThreadAccessHandler extends MyTriggers {
    global override void onBeforeUpdate(Map<Id, SObject> triggerOldMap) {
        stoThreadAccess.checkClosures((List<Thread__c>) records, triggerOldMap);
    }
}

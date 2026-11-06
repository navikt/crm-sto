global with sharing class stoMessageAccessHandler extends MyTriggers {
    global override void onBeforeInsert() {
        stoReplyContext.checkMessages((List<Message__c>) records);
    }
}

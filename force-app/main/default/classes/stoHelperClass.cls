public with sharing class stoHelperClass {
    @AuraEnabled(cacheable=true)
    public static List<STO_Category__mdt> getThemes() {
        return [
            SELECT Id, Label, STODescription__c, STOSort_Order__c
            FROM STO_Category__mdt
            ORDER BY STOSort_Order__c ASC
        ];
    }
    @AuraEnabled
    public static Id createRequest(String theme, String msgText) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.UseDefaultRule = true;

        //Todo - Connecet Userinfo to Case
        Case c = new Case();
        c.Subject = 'Skriv til oss - ' + theme;
        c.Origin = 'Web';

        try {
            List<User> uList = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
            c.AccountId = uList.get(0).AccountId;
        } catch (Exception e) {
            //dont do nothing
        }

        //Invoke assignment rules
        c.setOptions(dmlOpts);

        insert c;

        Thread__c thread = new Thread__c();
        thread.Messaging_Related_Object__c = c.Id;
        thread.Messaging_isPublic__c = true;
        thread.Messaging_From__c = UserInfo.getUserId();
        thread.Name = 'Skriv til oss - ' + theme;

        insert thread;

        Message__c msg = new Message__c();
        msg.Messaging_Message_Text__c = msgText;
        msg.Messaging_From__c = UserInfo.getUserId();
        msg.Messaging_Thread__c = thread.Id;
        insert msg;
        return thread.Id;
    }

    /**
     * Get all threads. Utilize sharing sets to filter the correct messages
     */
    @AuraEnabled(cacheable=true)
    public static List<Thread__c> getThreads() {
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, Messaging_Number_of_unread_Messages__c, Latest_Message_Datetime__c
            FROM Thread__c
            ORDER BY Latest_Message_Datetime__c DESC
        ];
        return threadList;
    }
    @AuraEnabled(cacheable=true)
    public static Message__c getLatestMessage(Id threadId) {
        List<Message__c> messageList = [
            SELECT Id, Messaging_Message_Text__c, Messaging_From__c
            FROM Message__c
            WHERE Messaging_Thread__c = :threadId
            ORDER BY CreatedDate DESC
        ];

        return messageList.get(0);
    }
}

public with sharing class stoHelperClass {
    /**
     * Get themes from custom metadata
     * @Author Lars Petter Johnsen
     */
    @AuraEnabled(cacheable=true)
    public static List<STO_Category__mdt> getThemes(String language) {
        System.debug(language);
        String lang;
        if(language.equals('no')){
            lang = 'Norwegian';
        }
        else if(language.equals('en-US')){
            lang = 'English';
        }
        
        return [
            SELECT Id, Label, STODescription__c, STOSort_Order__c
            FROM STO_Category__mdt
            WHERE STOLanguage__c =: lang
            ORDER BY STOSort_Order__c ASC
        ];
    }
    /**
     * Method to create case, thread and message when a user submits a write to us case
     * @author Lars Petter Johnsen
     * @date 08.06.21
     */
    @AuraEnabled
    public static Id createRequest(String theme, String msgText) {
    
        //Create case Record and insert it
        Case c = createCase(theme);
        Thread__c thread = createThread(c, theme);
        createMessage(thread, msgText);
       
        return thread.Id;
    }

    /**
     * Creates a STO Case.
     * Invokes Assignment rules using DMLOptions
     * @author Lars Petter Johnsen
     * @Date 08.06.2021
     */
    @TestVisible
    private static Case createCase(String theme){
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.assignmentRuleHeader.UseDefaultRule = true;

        Case c = new Case();
        c.Subject = 'Skriv til oss - ' + theme; //TODO: Handle Language changes
        c.Origin = 'Web';
        
        List<User> uList = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        c.AccountId = uList.get(0).AccountId;

        //Invoke assignment rules
        c.setOptions(dmlOpts);
        try{
            insert c;
        }
        catch(DmlException e){
            LoggerUtility logger = new LoggerUtility('Skriv til oss');
            logger.exception(e);
            logger.publish();
            
        }
        return c;
    }
    /**
     * Creates a thread to contain the STO conversation
     * @author Lars Petter Johnsen
     * @date 08.06.2021
     */
    @TestVisible
    private static Thread__c createThread(Case c, String theme){
        
        Thread__c thread = new Thread__c();
        thread.Messaging_Related_Object__c = c.Id;
        thread.Messaging_isPublic__c = true;
        thread.Messaging_From__c = UserInfo.getUserId();
        thread.Name = 'Skriv til oss - ' + theme;
        try{
            insert thread;
        }
        catch(DmlException e){
            LoggerUtility logger = new LoggerUtility('Skriv til oss');
            logger.exception(e);
            logger.publish();
        }
        return thread;
    }
    @TestVisible
    private static void createMessage(Thread__c t, String msgText){
        
        Message__c msg = new Message__c();
        msg.Messaging_Message_Text__c = msgText;
        msg.Messaging_From__c = UserInfo.getUserId();
        msg.Messaging_Thread__c = t.Id;
        try{
            insert msg;
        }
        catch(DmlException e){
            LoggerUtility logger = new LoggerUtility('Skriv til oss');
            logger.exception(e);
            logger.publish();
        }    
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

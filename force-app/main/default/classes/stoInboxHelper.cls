public with sharing class stoInboxHelper {
    /**
     * Get all threads. Utilize sharing sets to filter the correct messages
     * @Author Lars Petter
     */
    @AuraEnabled(cacheable=true)
    public static List<thread> getThreads() {
        List<thread> inboxlist = new List <thread>(); 
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c, CRM_Closed_Date__c 
            FROM Thread__c
            WHERE (CRM_Number_of_unread_Messages__c = 0 AND CRM_Closed_Date__c != null )
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for(Thread__c t : threadList){
            thread i = new thread(); 
            i.name = t.Name; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CRM_Closed_Date__c; 
            i.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c; 
            i.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            i.objectName = 'thread'; 
            inboxlist.add(i);  
        }
        //TODO: Add CN name when formula fields are moved 
        List<Conversation_Note__c> noteList = [
            SELECT Id, Name, LastModifiedDate, CreatedDate   
            FROM Conversation_Note__c 
            ORDER BY CreatedDate DESC
        ];
        for(Conversation_Note__c t : noteList){
            thread i = new thread(); 
            i.name = t.Name; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CreatedDate; 
            i.latestMessageDate = t.CreatedDate;
            i.objectName = 'conversation-note'; 
            inboxlist.add(i);  
        }
        return inboxlist;
    }
    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreads() {
        List<thread> inboxlist = new List <thread>(); 
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c, CRM_Closed_Date__c 
            FROM Thread__c 
            WHERE (CRM_Number_of_unread_Messages__c > 0 OR CRM_Closed_Date__c = null)
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for(Thread__c t : threadList){
            thread i = new thread(); 
            i.name = t.Name; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CRM_Closed_Date__c; 
            i.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c; 
            i.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            i.objectName = 'thread'; 
            inboxlist.add(i);  
        }
        return inboxlist; 
    }

    public class thread {
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Datetime lastModifiedDate;
        @AuraEnabled
        public Datetime closeDate;
        @AuraEnabled
        public Decimal numberOfUnreadMessages;
        @AuraEnabled
        public Datetime latestMessageDate;
        @AuraEnabled
        public String objectName;
    }

    @AuraEnabled(cacheable=true)
    public static message getLatestMessage(Id threadId) {
        message returntext = new message(); 
        String objectName = threadId.getSobjectType().getDescribe().getName(); 
        if(objectName == 'Thread__c'){
            objectName = 'skriv-til-oss'; 
            Message__c messageList = [
                SELECT Id, CRM_Message_Text__c, CRM_From_Contact__c
                FROM Message__c
                WHERE CRM_Thread__c = :threadId
                ORDER BY CRM_Sent_Datetime_Formula__c DESC LIMIT 1
            ];
            returntext.fromContact = messageList.CRM_From_Contact__c; 
            returntext.messageText = messageList.CRM_Message_Text__c; 
            returntext.recordId = messageList.Id; 
        }
        if(objectName == 'Conversation_Note__c'){
            objectName = 'samtalereferat'; 
            Conversation_Note__c cn = [SELECT Id, Name, CRM_Conversation_Note__c FROM Conversation_Note__c WHERE Id =: threadId LIMIT 1]; 
            returntext.fromContact = 'NAV'; 
            returntext.messageText = cn.CRM_Conversation_Note__c; 
            returntext.recordId = cn.Id; 
        }
        return returntext;
    }

    public class message {
        @AuraEnabled
        public Id recordId; 
        @AuraEnabled
        public String messageText; 
        @AuraEnabled
        public String fromContact; 
    }
}

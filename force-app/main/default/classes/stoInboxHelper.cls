public with sharing class stoInboxHelper {    
    
    //TODO: Use custom labels 

    @AuraEnabled(cacheable=true)
    public static List<thread> getThreads() {
        List<thread> inboxlist = new List <thread>(); 
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c, CRM_Closed_Date__c, STO_ExternalName__c  
            FROM Thread__c
            WHERE (CRM_Number_of_unread_Messages__c = 0 AND CRM_Closed_Date__c != null )
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for(Thread__c t : threadList){
            thread i = new thread(); 
            i.name = t.STO_ExternalName__c; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CRM_Closed_Date__c; 
            i.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c; 
            i.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            i.objectName = 'skriv-til-oss'; 
            i.status = 'Lukket'; 
            if(i.closeDate == null) i.status = 'Åpen'; 
            inboxlist.add(i);  
        }
        List<Conversation_Note__c> noteList = [
            SELECT Id, Name, LastModifiedDate, CreatedDate, CRM_Is_Read__c, STO_External_Name__c
            FROM Conversation_Note__c WHERE CRM_Is_Read__c = true AND CRM_Created_By_Ident__c != null 
            ORDER BY CreatedDate DESC
        ];
        for(Conversation_Note__c t : noteList){
            thread i = new thread(); 
            i.name = t.STO_External_Name__c; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CreatedDate; 
            i.numberOfUnreadMessages = 0; 
            i.latestMessageDate = t.CreatedDate;
            i.objectName = 'samtalereferat'; 
            i.status = 'Lukket'; 
            inboxlist.add(i);  
        }
        return inboxlist;
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreads() {
        List<thread> inboxlist = new List <thread>(); 
        List<Thread__c> threadList = [
            SELECT Id, Name, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c, CRM_Closed_Date__c, STO_ExternalName__c 
            FROM Thread__c 
            WHERE (CRM_Number_of_unread_Messages__c > 0 OR CRM_Closed_Date__c = null)
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for(Thread__c t : threadList){
            thread i = new thread(); 
            i.name = t.STO_ExternalName__c; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CRM_Closed_Date__c; 
            i.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c; 
            i.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            i.objectName = 'skriv-til-oss'; 
            i.status = 'Lukket'; 
            if(i.closeDate == null) i.status = 'Åpen'; 
            inboxlist.add(i);  
        }
        List<Conversation_Note__c> noteList = [
            SELECT Id, Name, LastModifiedDate, CreatedDate, CRM_Is_Read__c, STO_External_Name__c
            FROM Conversation_Note__c WHERE CRM_Is_Read__c = false AND CRM_Created_By_Ident__c != null 
            ORDER BY CreatedDate DESC
        ];
        for(Conversation_Note__c t : noteList){
            thread i = new thread(); 
            i.name = t.STO_External_Name__c; 
            i.recordId = t.Id; 
            i.lastModifiedDate = t.LastModifiedDate; 
            i.closeDate = t.CreatedDate; 
            i.numberOfUnreadMessages = 1; 
            i.latestMessageDate = t.CreatedDate;
            i.objectName = 'samtalereferat'; 
            i.status = 'Lukket'; 
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
        @AuraEnabled
        public String status;
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
                WHERE CRM_Thread__c = :threadId AND CRM_Type__c = 'Message'
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

    @AuraEnabled
    public static void markAsRead(Id conversationNoteId) {
        List<Conversation_Note__c> noteList = [SELECT Id FROM Conversation_Note__c WHERE CRM_Is_Read__c = FALSE AND Id = :conversationNoteId LIMIT 1];
        for (Conversation_Note__c cn : noteList) {
            cn.CRM_Is_Read__c = true;
            cn.CRM_Read_Date__c = DateTime.now();
        }
        update noteList;
    }
}

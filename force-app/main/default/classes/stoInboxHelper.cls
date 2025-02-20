public with sharing class stoInboxHelper {
    //TODO: Use custom labels

    @AuraEnabled(cacheable=true)
    public static List<thread> getThreads() {
        List<thread> inboxlist = new List<thread>();
        List<Thread__c> threadList = [
            SELECT
                Id,
                LastModifiedDate,
                CRM_Number_of_unread_Messages__c,
                CRM_Latest_Message_Datetime__c,
                CRM_Closed_Date__c,
                STO_ExternalName__c,
                CRM_Is_Closed__c,
                CRM_Thread_Type__c,
                CRM_Related_Object__c,
                Name,
                NKS_Inbox_Title__c,
                NKS_Inbox_Theme__c,
                (
                    SELECT Id, CRM_Message_Text__c, CRM_External_Message__c
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    ORDER BY CRM_Sent_Datetime_Formula__c DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE
                CRM_Number_of_unread_Messages__c = 0
                AND CRM_Is_Closed__C = TRUE
                AND CRM_Thread_Type__c IN ('STO', 'BTO', 'STB', 'CHAT')
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for (Thread__c t : threadList) {
            inboxlist.add(formatThread(t));
        }
        List<Conversation_Note__c> noteList = [
            SELECT
                Id,
                LastModifiedDate,
                CRM_Date_Time_Registered__c,
                STO_External_Name__c,
                CRM_Conversation_Note__c,
                Name
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = TRUE AND CRM_Created_By_Ident__c != NULL
            ORDER BY CRM_Date_Time_Registered__c DESC
        ];
        for (Conversation_Note__c t : noteList) {
            inboxlist.add(formatConversationNote(t, true));
        }
        return inboxlist;
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreads() {
        List<thread> inboxlist = new List<thread>();
        List<Thread__c> threadList = [
            SELECT
                Id,
                LastModifiedDate,
                CRM_Number_of_unread_Messages__c,
                CRM_Latest_Message_Datetime__c,
                CRM_Closed_Date__c,
                STO_ExternalName__c,
                CRM_Is_Closed__c,
                CRM_Thread_Type__c,
                CRM_Related_Object__c,
                Name,
                NKS_Inbox_Title__c,
                NKS_Inbox_Theme__c,
                (
                    SELECT Id, CRM_Message_Text__c, CRM_External_Message__c
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' OR CRM_Type__c = 'Info'
                    ORDER BY CRM_Sent_Datetime_Formula__c DESC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE
                (CRM_Number_of_unread_Messages__c > 0
                OR CRM_Is_Closed__c = FALSE)
                AND CRM_Thread_Type__c IN ('STO', 'BTO', 'STB', 'CHAT')
            ORDER BY CRM_Latest_Message_Datetime__c DESC
        ];
        for (Thread__c t : threadList) {
            inboxlist.add(formatThread(t));
        }
        List<Conversation_Note__c> noteList = [
            SELECT
                Id,
                LastModifiedDate,
                CRM_Date_Time_Registered__c,
                STO_External_Name__c,
                CRM_Conversation_Note__c,
                Name
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = FALSE AND CRM_Created_By_Ident__c != NULL
            ORDER BY CRM_Date_Time_Registered__c DESC
        ];
        for (Conversation_Note__c t : noteList) {
            inboxlist.add(formatConversationNote(t, false));
        }
        return inboxlist;
    }

    public static Thread formatThread(Thread__c t) {
        if (t.Messages__r != null && t.Messages__r.size() > 0) {
            Thread thread = new Thread();
            Message message = new Message();
            thread.name = t.STO_ExternalName__c;
            thread.recordId = t.CRM_Thread_Type__c == 'CHAT' ? t.CRM_Related_Object__c : t.Id;
            thread.lastModifiedDate = t.LastModifiedDate;
            thread.closeDate = t.CRM_Closed_Date__c;
            thread.numberOfUnreadMessages = t.CRM_Number_of_unread_Messages__c;
            thread.latestMessageDate = t.CRM_Latest_Message_Datetime__c;
            thread.objectName = t.CRM_Thread_Type__c == 'CHAT'
                ? 'chat'
                : (t.CRM_Thread_Type__c == 'BTO' ? 'beskjed-til-oss' : 'skriv-til-oss');
            thread.status = (t.CRM_Is_Closed__c) ? 'Avsluttet' : 'Åpen';
            thread.recordName = t.Name;
            message.recordId = t.Messages__r[0]?.Id;
            message.messageText = t.Messages__r[0]
                ?.CRM_Message_Text__c
                ?.replaceAll('<[^>]+>', ' ')
                .replaceAll('(\\r|\\n)+', ' ');
            message.isExternal = t.Messages__r[0]?.CRM_External_Message__c;
            thread.latestmessage = message;
            thread.inboxTitle = t.NKS_Inbox_Title__c;
            thread.inboxTheme = t.NKS_Inbox_Theme__c;
            return thread;
        }
        return null;
    }

    public static thread formatConversationNote(Conversation_Note__c t, Boolean read) {
        thread i = new thread();
        message m = new message();
        i.name = t.STO_External_Name__c;
        i.recordId = t.Id;
        i.lastModifiedDate = t.LastModifiedDate;
        i.closeDate = t.CRM_Date_Time_Registered__c;
        i.numberOfUnreadMessages = read ? 0 : 1;
        i.latestMessageDate = t.CRM_Date_Time_Registered__c;
        i.objectName = 'samtalereferat';
        i.status = 'Avsluttet';
        i.recordName = t.Name;
        m.messageText = t.CRM_Conversation_Note__c?.replaceAll('<[^>]+>', ' ').replaceAll('(\\r|\\n)+', ' ');
        m.recordId = t.Id;
        i.latestmessage = m;
        return i;
    }

    public class Thread {
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
        @AuraEnabled
        public message latestmessage;
        @AuraEnabled
        public String recordName;
        @AuraEnabled
        public String inboxTitle;
        @AuraEnabled
        public String inboxTheme;
    }

    public class Message {
        @AuraEnabled
        public Id recordId;
        @AuraEnabled
        public String messageText;
        @Auraenabled
        public Boolean isExternal;
    }

    @AuraEnabled
    public static void markAsRead(Id conversationNoteId) {
        List<Conversation_Note__c> noteList = [
            SELECT Id
            FROM Conversation_Note__c
            WHERE CRM_Is_Read__c = FALSE AND Id = :conversationNoteId
            LIMIT 1
        ];
        for (Conversation_Note__c cn : noteList) {
            cn.CRM_Is_Read__c = true;
            cn.CRM_Read_Date__c = DateTime.now();
        }
        update noteList;
    }
}

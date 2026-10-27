public with sharing class stoInboxHelper {
    @TestVisible
    private static final Integer PAGE_SIZE = 50;

    @AuraEnabled(cacheable=true)
    public static List<thread> getThreads() {
        return getThreadsForPerson(null);
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getThreadsForPerson(Id representedAccountId) {
        return getInboxPage(representedAccountId, null, null).older;
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreads() {
        return getRecentThreadsForPerson(null);
    }

    @AuraEnabled(cacheable=true)
    public static List<thread> getRecentThreadsForPerson(Id representedAccountId) {
        return getInboxPage(representedAccountId, null, null).recent;
    }

    public class InboxPage {
        @AuraEnabled
        public List<thread> recent = new List<thread>();
        @AuraEnabled
        public List<thread> older = new List<thread>();
        @AuraEnabled
        public Id beforeThreadId;
        @AuraEnabled
        public Id beforeNoteId;
        @AuraEnabled
        public Boolean hasMore;
    }

    // Later pages have no wire handle to refresh after a reader returns from a thread.
    @AuraEnabled
    public static InboxPage getNextInboxPage(Id representedAccountId, Id beforeThreadId, Id beforeNoteId) {
        return getInboxPage(representedAccountId, beforeThreadId, beforeNoteId);
    }

    @AuraEnabled(cacheable=true)
    public static InboxPage getInboxPage(Id representedAccountId, Id beforeThreadId, Id beforeNoteId) {
        Id accountId = stoPersonContext.resolveAccountId(representedAccountId);
        Id viewerContactId = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId;
        InboxPage page = new InboxPage();
        page.beforeThreadId = beforeThreadId;
        page.beforeNoteId = beforeNoteId;
        Integer fetchSize = PAGE_SIZE + 1;
        Datetime threadDate;
        String threadCursor = '';
        if (beforeThreadId != null) {
            Thread__c cursor = [
                SELECT CRM_Latest_Message_Datetime__c
                FROM Thread__c
                WHERE Id = :beforeThreadId AND CRM_Account__c = :accountId
            ];
            threadDate = cursor.CRM_Latest_Message_Datetime__c;
            threadCursor = threadDate == null
                ? ' AND CRM_Latest_Message_Datetime__c = NULL AND Id < :beforeThreadId'
                : ' AND (CRM_Latest_Message_Datetime__c < :threadDate OR CRM_Latest_Message_Datetime__c = NULL' +
                  ' OR (CRM_Latest_Message_Datetime__c = :threadDate AND Id < :beforeThreadId))';
        }
        List<Thread__c> threadList = Database.query(
            'SELECT Id, LastModifiedDate, CRM_Number_of_unread_Messages__c, CRM_Latest_Message_Datetime__c,' +
                ' CRM_Closed_Date__c, STO_ExternalName__c, CRM_Is_Closed__c, CRM_Thread_Type__c, CRM_Related_Object__c,' +
                ' CRM_Contact__c, CRM_Contact__r.Name, Name, NKS_Inbox_Title__c, NKS_Inbox_Theme__c, CRM_Theme_Group_Name__c, STO_Category__c,' +
                ' (SELECT Id, CRM_Message_Text__c, CRM_External_Message__c FROM Messages__r' +
                ' WHERE CRM_Type__c IN (\'Message\', \'Info\') ORDER BY CRM_Sent_Datetime_Formula__c DESC, Id DESC LIMIT 1)' +
                ' FROM Thread__c WHERE CRM_Account__c = :accountId AND CRM_Thread_Type__c IN (\'STO\', \'BTO\', \'STB\', \'CHAT\')' +
                threadCursor +
                ' ORDER BY CRM_Latest_Message_Datetime__c DESC NULLS LAST, Id DESC LIMIT :fetchSize'
        );
        page.hasMore = threadList.size() > PAGE_SIZE;
        if (page.hasMore)
            threadList.remove(PAGE_SIZE);
        Map<Id, Decimal> unread = stoThreadReadState.unread(threadList, viewerContactId);
        Map<Id, Thread__c> byId = new Map<Id, Thread__c>(threadList);
        Map<Id, Message__c> starters = new Map<Id, Message__c>();
        for (Thread__c t : [
            SELECT
                Id,
                (
                    SELECT CRM_From_Contact__c, CRM_From_Contact__r.Name
                    FROM Messages__r
                    WHERE CRM_Type__c = 'Message' AND (CRM_External_Message__c = TRUE OR CRM_From_Contact__c != NULL)
                    ORDER BY CRM_Sent_date__c ASC, CreatedDate ASC, Id ASC
                    LIMIT 1
                )
            FROM Thread__c
            WHERE Id IN :byId.keySet()
        ]) {
            if (!t.Messages__r.isEmpty())
                starters.put(t.Id, t.Messages__r[0]);
        }
        for (Thread__c t : threadList) {
            page.beforeThreadId = t.Id;
            Thread item = formatThread(t);
            if (item == null)
                continue;
            item.numberOfUnreadMessages = unread.get(t.Id);
            Message__c first = starters.get(t.Id);
            if (t.CRM_Thread_Type__c != 'CHAT') {
                item.inboxSenderLabel = stoThreadAccess.inboxSenderLabel(viewerContactId, first);
            }
            if (!t.CRM_Is_Closed__c || item.numberOfUnreadMessages > 0)
                page.recent.add(item);
            else
                page.older.add(item);
        }
        threadList.clear();
        byId.clear();
        starters.clear();
        Datetime noteDate;
        String noteCursor = '';
        if (beforeNoteId != null) {
            Conversation_Note__c cursor = [
                SELECT CRM_Date_Time_Registered__c
                FROM Conversation_Note__c
                WHERE Id = :beforeNoteId AND CRM_Account__c = :accountId
            ];
            noteDate = cursor.CRM_Date_Time_Registered__c;
            noteCursor = noteDate == null
                ? ' AND CRM_Date_Time_Registered__c = NULL AND Id < :beforeNoteId'
                : ' AND (CRM_Date_Time_Registered__c < :noteDate OR CRM_Date_Time_Registered__c = NULL' +
                  ' OR (CRM_Date_Time_Registered__c = :noteDate AND Id < :beforeNoteId))';
        }
        List<Conversation_Note__c> noteList = Database.query(
            'SELECT Id, LastModifiedDate, CRM_Is_Read__c, CRM_Date_Time_Registered__c, STO_External_Name__c,' +
                ' CRM_Conversation_Note__c, Name, CRM_Theme_Group_Name__c FROM Conversation_Note__c' +
                ' WHERE CRM_Created_By_Ident__c != NULL AND CRM_Account__c = :accountId' +
                noteCursor +
                ' ORDER BY CRM_Date_Time_Registered__c DESC NULLS LAST, Id DESC LIMIT :fetchSize'
        );
        if (noteList.size() > PAGE_SIZE) {
            page.hasMore = true;
            noteList.remove(PAGE_SIZE);
        }
        for (Conversation_Note__c t : noteList) {
            page.beforeNoteId = t.Id;
            Thread item = formatConversationNote(t, t.CRM_Is_Read__c);
            if (t.CRM_Is_Read__c)
                page.older.add(item);
            else
                page.recent.add(item);
        }
        return page;
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
            message.messageText = preview(t.Messages__r[0]?.CRM_Message_Text__c)?.left(500);
            message.isExternal = t.Messages__r[0]?.CRM_External_Message__c;
            thread.latestmessage = message;
            thread.inboxTitle = t.NKS_Inbox_Title__c;
            thread.inboxTheme = t.NKS_Inbox_Theme__c;
            thread.category = t.CRM_Thread_Type__c == 'CHAT' ? t.CRM_Theme_Group_Name__c : t.STO_Category__c;
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
        m.messageText = preview(t.CRM_Conversation_Note__c);
        m.recordId = t.Id;
        i.latestmessage = m;
        i.category = t.CRM_Theme_Group_Name__c;
        return i;
    }

    private static String preview(String text) {
        if (text == null)
            return null;
        return text.replaceAll('<[^>]+>', ' ').replaceAll('(\\r|\\n)+', ' ').left(1000);
    }

    public class Thread {
        @AuraEnabled
        public String inboxSenderLabel;
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
        @AuraEnabled
        public String category;
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

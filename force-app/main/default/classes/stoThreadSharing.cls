public with sharing class stoThreadSharing {
    public static Id prepareInboxAccess(Id representedAccountId) {
        Id accountId = stoPersonContext.resolveAccountId(representedAccountId);
        if (accountId != null) {
            new Shares().grantInboxRead(accountId);
        }
        return accountId;
    }

    public static void shareWithSubject(Thread__c thread) {
        if (thread.CRM_Contact__c != null) {
            new Shares().grantSubjectRead(thread);
        }
    }

    // Callers authorize the account before this narrowly scoped system-mode sharing operation.
    private without sharing class Shares {
        public void grantInboxRead(Id accountId) {
            Account subject = [SELECT Id FROM Account WHERE Id = :accountId WITH SYSTEM_MODE FOR UPDATE];
            List<Thread__c> threads = [
                SELECT Id, OwnerId
                FROM Thread__c
                WHERE CRM_Account__c = :subject.Id AND CRM_Thread_Type__c IN ('STO', 'STB', 'BTO', 'CHAT')
                WITH SYSTEM_MODE
            ];
            grantRead(threads, new Set<Id>{ UserInfo.getUserId() });
            grantNoteRead(subject.Id);
        }

        public void grantSubjectRead(Thread__c thread) {
            Set<Id> subjectUserIds = new Set<Id>();
            for (User subject : [
                SELECT Id
                FROM User
                WHERE ContactId = :thread.CRM_Contact__c AND IsActive = TRUE AND IsPortalEnabled = TRUE
                WITH SYSTEM_MODE
            ]) {
                subjectUserIds.add(subject.Id);
            }
            grantRead([SELECT Id, OwnerId FROM Thread__c WHERE Id = :thread.Id WITH SYSTEM_MODE], subjectUserIds);
        }

        private void grantRead(List<Thread__c> threads, Set<Id> readerIds) {
            if (threads.isEmpty() || readerIds.isEmpty()) {
                return;
            }
            Set<Id> threadIds = new Map<Id, Thread__c>(threads).keySet();
            Set<String> existing = new Set<String>();
            for (Thread__Share share : [
                SELECT ParentId, UserOrGroupId
                FROM Thread__Share
                WHERE ParentId IN :threadIds AND UserOrGroupId IN :readerIds
                WITH SYSTEM_MODE
            ]) {
                existing.add(share.ParentId + ':' + share.UserOrGroupId);
            }
            List<Thread__Share> shares = new List<Thread__Share>();
            for (Thread__c thread : threads) {
                for (Id readerId : readerIds) {
                    if (thread.OwnerId != readerId && !existing.contains(thread.Id + ':' + readerId)) {
                        shares.add(
                            new Thread__Share(
                                ParentId = thread.Id,
                                UserOrGroupId = readerId,
                                AccessLevel = 'Read',
                                RowCause = Schema.Thread__Share.RowCause.STO_Family_Read__c
                            )
                        );
                    }
                }
            }
            if (!shares.isEmpty()) {
                insert as system shares;
            }
        }

        private void grantNoteRead(Id accountId) {
            Id readerId = UserInfo.getUserId();
            List<Conversation_Note__c> notes = [
                SELECT Id, OwnerId
                FROM Conversation_Note__c
                WHERE CRM_Account__c = :accountId AND CRM_Created_By_Ident__c != NULL
                WITH SYSTEM_MODE
            ];
            if (notes.isEmpty()) {
                return;
            }
            Set<Id> noteIds = new Map<Id, Conversation_Note__c>(notes).keySet();
            Set<Id> existing = new Set<Id>();
            for (Conversation_Note__Share share : [
                SELECT ParentId
                FROM Conversation_Note__Share
                WHERE ParentId IN :noteIds AND UserOrGroupId = :readerId
                WITH SYSTEM_MODE
            ]) {
                existing.add(share.ParentId);
            }
            List<Conversation_Note__Share> shares = new List<Conversation_Note__Share>();
            for (Conversation_Note__c note : notes) {
                if (note.OwnerId != readerId && !existing.contains(note.Id)) {
                    shares.add(
                        new Conversation_Note__Share(
                            ParentId = note.Id,
                            UserOrGroupId = readerId,
                            AccessLevel = 'Read',
                            RowCause = Schema.Conversation_Note__Share.RowCause.STO_Family_Read__c
                        )
                    );
                }
            }
            if (!shares.isEmpty()) {
                insert as system shares;
            }
        }
    }
}

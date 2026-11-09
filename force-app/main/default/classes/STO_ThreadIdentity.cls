public without sharing class STO_ThreadIdentity {
    @TestVisible
    private static AccountIdentity cachedCurrentUserAccountIdentity;
    @TestVisible
    private static Id cachedUserId;

    public static AccountIdentity getCurrentUserAccountIdentity() {
        if (cachedCurrentUserAccountIdentity == null || cachedUserId != UserInfo.getUserId()) {
            User currentUser = [
                SELECT AccountId, ContactId, Account.CRM_Person__r.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            cachedCurrentUserAccountIdentity = new AccountIdentity(
                currentUser.AccountId,
                currentUser.ContactId,
                currentUser.Account?.CRM_Person__r?.Name
            );
            cachedUserId = UserInfo.getUserId();
        }
        if (cachedCurrentUserAccountIdentity.accountId == null || cachedCurrentUserAccountIdentity.contactId == null) {
            throw new stoHelperClass.NoAccountFoundException('Current user account or contact was not found.');
        }
        return cachedCurrentUserAccountIdentity;
    }

    public static AccountIdentity getRepresentedAccountIdentity(String personIdentifier) {
        if (String.isBlank(personIdentifier)) {
            throw new stoHelperClass.InvalidThreadDataException('A represented person identifier is required.');
        }
        List<Account> accounts = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE CRM_Person__r.Name = :personIdentifier
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (accounts.size() != 1 || accounts[0].PersonContactId == null) {
            stoHelperClass.logError('Unable to resolve a unique account and contact for the represented person.');
            throw new stoHelperClass.ChildAccountNotFoundException(
                'A unique account and contact for the represented person was not found.'
            );
        }
        return new AccountIdentity(accounts[0].Id, accounts[0].PersonContactId, personIdentifier);
    }

    public class AccountIdentity {
        public Id accountId { get; private set; }
        public Id contactId { get; private set; }
        public String personIdentifier { get; private set; }

        public AccountIdentity(Id accountId, Id contactId, String personIdentifier) {
            this.accountId = accountId;
            this.contactId = contactId;
            this.personIdentifier = personIdentifier;
        }
    }
}

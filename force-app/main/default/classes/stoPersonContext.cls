public with sharing class stoPersonContext {
    @TestVisible
    private static Map<Id, User> viewersById = new Map<Id, User>();
    private static Map<Id, Set<String>> childIdentsByUser = new Map<Id, Set<String>>();

    public static User currentUser() {
        Id viewerId = UserInfo.getUserId();
        if (!viewersById.containsKey(viewerId)) {
            // Preserve legacy identity-field access, restricted to the authenticated actor, across class API versions.
            viewersById.put(
                viewerId,
                [
                    SELECT
                        AccountId,
                        ContactId,
                        IsActive,
                        IsPortalEnabled,
                        UserType,
                        Account.IsPersonAccount,
                        Account.PersonContactId,
                        Account.CRM_Person__r.Name
                    FROM User
                    WHERE Id = :viewerId
                    WITH SYSTEM_MODE
                ]
            );
        }
        return viewersById.get(viewerId);
    }

    private static Id currentPersonAccountId() {
        User viewer = currentUser();
        if (
            !viewer.IsActive ||
            viewer.AccountId == null ||
            viewer.ContactId == null ||
            viewer.Account?.IsPersonAccount != true ||
            viewer.Account.PersonContactId != viewer.ContactId
        ) {
            return null;
        }
        return viewer.AccountId;
    }

    public static AccountIdentity getCurrentUserAccountIdentity() {
        User viewer = currentUser();
        Id accountId = currentPersonAccountId();
        if (accountId == null) {
            throw new stoHelperClass.NoAccountFoundException('Current user account or contact was not found.');
        }
        return new AccountIdentity(accountId, viewer.ContactId, viewer.Account?.CRM_Person__r?.Name);
    }

    public static AccountIdentity resolveThreadAccountIdentity(String representedIdentifier) {
        AccountIdentity actor = getCurrentUserAccountIdentity();
        if (representedIdentifier == null) {
            return actor;
        }
        if (String.isBlank(representedIdentifier)) {
            throw new stoHelperClass.InvalidThreadDataException('A represented person identifier is required.');
        }
        if (!verifyRepresentation(representedIdentifier)) {
            throw new stoHelperClass.NoParentalResponsibilityException('Parental responsibility was not confirmed.');
        }
        return getRepresentedAccountIdentity(representedIdentifier);
    }

    public static AccountIdentity getRepresentedAccountIdentity(String personIdentifier) {
        if (String.isBlank(personIdentifier)) {
            throw new stoHelperClass.InvalidThreadDataException('A represented person identifier is required.');
        }
        String adultBirthDate = String.valueOf(Date.today().addYears(-18));
        String today = String.valueOf(Date.today());
        List<Account> accounts = new RepresentedAccounts().find(personIdentifier);
        if (
            accounts.size() != 1 ||
            accounts[0].PersonContactId == null ||
            accounts[0].CRM_Person__r.INT_Confidential__c != 'UGRADERT' ||
            String.isBlank(accounts[0].CRM_Person__r.INT_DateOfBirth__c) ||
            accounts[0].CRM_Person__r.INT_DateOfBirth__c.compareTo(adultBirthDate) <= 0 ||
            accounts[0].CRM_Person__r.INT_DateOfBirth__c.compareTo(today) > 0
        ) {
            stoHelperClass.logError(
                'Unable to resolve a unique eligible account and contact for the represented person.'
            );
            throw new stoHelperClass.ChildAccountNotFoundException(
                'A unique eligible account and contact for the represented person was not found.'
            );
        }
        return new AccountIdentity(accounts[0].Id, accounts[0].PersonContactId, personIdentifier);
    }

    @AuraEnabled(cacheable=true)
    public static List<PersonOption> getRepresentableChildren() {
        List<PersonOption> options = new List<PersonOption>();
        for (Account child : authorizedChildren()) {
            options.add(new PersonOption(child));
        }
        return options;
    }

    public static Id resolveAccountId(Id representedAccountId) {
        Id ownAccountId = currentPersonAccountId();
        if (ownAccountId != null) {
            if (representedAccountId == null || representedAccountId == ownAccountId) {
                return ownAccountId;
            }
            for (PersonOption child : getRepresentableChildren()) {
                if (child.value == representedAccountId) {
                    return child.value;
                }
            }
        }
        AuraHandledException error = new AuraHandledException('Du har ikke tilgang til samtalene for denne personen.');
        error.setMessage('Du har ikke tilgang til samtalene for denne personen.');
        throw error;
    }

    public static Integer ageInYears(Date birthDate) {
        Integer age = Date.today().year() - birthDate.year();
        return birthDate.addYears(age) > Date.today() ? age - 1 : age;
    }

    public static Boolean verifyRepresentation(String representedPersonIdentifier) {
        if (String.isBlank(representedPersonIdentifier)) {
            throw new stoHelperClass.InvalidThreadDataException('A represented person identifier is required.');
        }
        Account parent = authenticatedParent();
        if (parent == null) {
            return false;
        }
        if (String.isBlank(parent.CRM_Person__r?.Name)) {
            throw invalidVerificationResponse('Actor identifier unavailable');
        }
        HttpResponse response;
        // verifiser also enforces age/confidentiality; keep local eligibility checks as defense in depth.
        // The installed controller returns HttpResponse; migrate only when its boolean API is available.
        try {
            response = stoScratchSupport.isEnabled()
                ? (HttpResponse) stoScratchSupport.invoke(
                      'verifiser',
                      new Map<String, Object>{
                          'parentIdent' => parent.CRM_Person__r?.Name,
                          'childIdent' => representedPersonIdentifier
                      }
                  )
                : NKS_ForeldreansvarService.verifiser(parent.CRM_Person__r?.Name, representedPersonIdentifier);
        } catch (Exception error) {
            throw invalidVerificationResponse('Dependency failure: ' + error.getTypeName());
        }
        if (response == null) {
            throw invalidVerificationResponse('Missing response');
        }
        if (response.getStatusCode() == 204 || response.getStatusCode() == 404) {
            return false;
        }
        if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
            throw invalidVerificationResponse('Unexpected status or empty body: ' + response.getStatusCode());
        }
        Object body;
        try {
            body = JSON.deserializeUntyped(response.getBody());
        } catch (System.JSONException error) {
            throw invalidVerificationResponse('Malformed JSON');
        }
        if (!(body instanceof Map<String, Object>)) {
            throw invalidVerificationResponse('Invalid response shape');
        }
        Object canRepresent = ((Map<String, Object>) body).get('kanRepresentere');
        if (!(canRepresent instanceof Boolean)) {
            throw invalidVerificationResponse('Missing boolean decision');
        }
        return (Boolean) canRepresent;
    }

    private static List<Account> authorizedChildren() {
        Set<String> childIdents = verifiedChildIdents();
        if (childIdents.isEmpty()) {
            return new List<Account>();
        }
        // PersonHandler stores birth dates as ISO strings, not Account.PersonBirthdate.
        String adultBirthDate = String.valueOf(Date.today().addYears(-18));
        String today = String.valueOf(Date.today());
        return [
            SELECT Id, Name, PersonContactId, CRM_Person__r.Name, CRM_Person__r.INT_DateOfBirth__c
            FROM Account
            WHERE
                IsPersonAccount = TRUE
                AND CRM_Person__r.Name IN :childIdents
                AND CRM_Person__r.INT_Confidential__c = 'UGRADERT'
                AND CRM_Person__r.INT_DateOfBirth__c > :adultBirthDate
                AND CRM_Person__r.INT_DateOfBirth__c <= :today
            ORDER BY Name
        ];
    }

    private static Set<String> verifiedChildIdents() {
        Id actorId = UserInfo.getUserId();
        if (childIdentsByUser.containsKey(actorId)) {
            return childIdentsByUser.get(actorId);
        }
        Account parent = authenticatedParent();
        if (parent == null) {
            return new Set<String>();
        }
        HttpResponse response = stoScratchSupport.isEnabled()
            ? (HttpResponse) stoScratchSupport.invoke(
                  'barn',
                  new Map<String, Object>{ 'parentIdent' => parent.CRM_Person__r?.Name }
              )
            : NKS_ForeldreansvarService.barn(parent.CRM_Person__r?.Name);
        Set<String> childIdents = new Set<String>();
        if (response.getStatusCode() != 204 && response.getStatusCode() != 404) {
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                throw invalidResponse();
            }
            BarnResponse body;
            try {
                body = (BarnResponse) JSON.deserialize(response.getBody(), BarnResponse.class);
            } catch (System.JSONException error) {
                throw invalidResponse();
            }
            if (body == null || body.barn == null) {
                throw invalidResponse();
            }
            for (Barn child : body.barn) {
                if (child == null || String.isBlank(child.ident)) {
                    throw invalidResponse();
                }
                childIdents.add(child.ident);
            }
        }
        childIdentsByUser.put(actorId, childIdents);
        return childIdents;
    }

    private static Account authenticatedParent() {
        return currentPersonAccountId() == null ? null : currentUser().Account;
    }

    private static AuraHandledException invalidVerificationResponse(String reason) {
        String correlationId = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        LoggerUtility logger = new LoggerUtility('Foreldreansvar');
        logger.error(
            'Representation verification failed. LoggId: ' + correlationId + '. ' + reason,
            null,
            CRM_ApplicationDomain.Domain.NKS
        );
        logger.publish();
        return stoHelperClass.handledError(
            'Kunne ikke verifisere foreldreansvar. Prøv igjen senere. LoggId: ' + correlationId
        );
    }

    private static AuraHandledException invalidResponse() {
        LoggerUtility logger = new LoggerUtility('Foreldreansvar');
        logger.error('Ugyldig svar ved henting av barn fra nks-foreldreansvar', null, CRM_ApplicationDomain.Domain.NKS);
        logger.publish();
        return new AuraHandledException('Kunne ikke hente barn du kan representere. Prøv igjen senere.');
    }

    private class BarnResponse {
        public List<Barn> barn;
    }

    private class Barn {
        public String ident;
    }

    private without sharing class RepresentedAccounts {
        public List<Account> find(String personIdentifier) {
            return [
                SELECT Id, PersonContactId, CRM_Person__r.INT_Confidential__c, CRM_Person__r.INT_DateOfBirth__c
                FROM Account
                WHERE IsPersonAccount = TRUE AND CRM_Person__r.Name = :personIdentifier
                WITH SYSTEM_MODE
                LIMIT 2
            ];
        }
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

    public class PersonOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Id value;
        @AuraEnabled
        public String representedPersonIdentifier;

        public PersonOption(Account child) {
            label = child.Name;
            String birthDateValue = child.CRM_Person__r?.INT_DateOfBirth__c;
            if (String.isNotBlank(birthDateValue)) {
                label += ' (' + ageInYears(Date.valueOf(birthDateValue)) + ' år)';
            }
            value = child.Id;
            representedPersonIdentifier = child.CRM_Person__r?.Name;
        }
    }
}

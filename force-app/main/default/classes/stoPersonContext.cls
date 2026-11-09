public with sharing class stoPersonContext {
    private static Map<Id, User> viewersById = new Map<Id, User>();
    private static Map<Id, Map<String, Barn>> childrenByUser = new Map<Id, Map<String, Barn>>();

    public static User currentUser() {
        Id viewerId = UserInfo.getUserId();
        if (!viewersById.containsKey(viewerId)) {
            // Preserve legacy identity-field access, restricted to the authenticated actor, across class API versions.
            viewersById.put(
                viewerId,
                [
                    SELECT AccountId, ContactId, IsActive, IsPortalEnabled, UserType
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
        if (!viewer.IsActive || viewer.AccountId == null || viewer.ContactId == null) {
            return null;
        }
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Id = :viewer.AccountId AND IsPersonAccount = TRUE AND PersonContactId = :viewer.ContactId
            WITH SYSTEM_MODE
        ];
        return accounts.isEmpty() ? null : accounts[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<PersonOption> getRepresentableChildren() {
        Map<String, Barn> children = verifiedChildren();
        List<PersonOption> options = new List<PersonOption>();
        for (Account child : authorizedChildren(children.keySet())) {
            Barn details = children.get(child.CRM_Person__r.Name);
            // ToDo: Check if this check is already done in foreldreansvar app
            if (details.alder < 18) {
                options.add(new PersonOption(child.Id, details));
            }
        }
        options.sort();
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
        Account parent = authenticatedParent();
        if (parent == null) {
            return false;
        }
        HttpResponse response = stoScratchSupport.isEnabled()
            ? (HttpResponse) stoScratchSupport.invoke(
                  'verifiser',
                  new Map<String, Object>{
                      'parentIdent' => parent.CRM_Person__r?.Name,
                      'childIdent' => representedPersonIdentifier
                  }
              )
            : NKS_ForeldreansvarService.verifiser(parent.CRM_Person__r?.Name, representedPersonIdentifier);
        if (response.getStatusCode() == 204 || response.getStatusCode() == 404) {
            return false;
        }
        if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
            throw invalidVerificationResponse();
        }
        Object body;
        try {
            body = JSON.deserializeUntyped(response.getBody());
        } catch (System.JSONException error) {
            throw invalidVerificationResponse();
        }
        if (!(body instanceof Map<String, Object>)) {
            throw invalidVerificationResponse();
        }
        Object canRepresent = ((Map<String, Object>) body).get('kanRepresentere');
        if (!(canRepresent instanceof Boolean)) {
            throw invalidVerificationResponse();
        }
        return (Boolean) canRepresent;
    }

    private static List<Account> authorizedChildren(Set<String> childIdents) {
        if (childIdents.isEmpty()) {
            return new List<Account>();
        }
        return [
            SELECT Id, CRM_Person__r.Name
            FROM Account
            WHERE
                IsPersonAccount = TRUE
                AND CRM_Person__r.Name IN :childIdents
                AND CRM_Person__r.INT_Confidential__c = 'UGRADERT'
        ];
    }

    private static Map<String, Barn> verifiedChildren() {
        Id actorId = UserInfo.getUserId();
        if (childrenByUser.containsKey(actorId)) {
            return childrenByUser.get(actorId);
        }
        Account parent = authenticatedParent();
        if (parent == null) {
            return new Map<String, Barn>();
        }
        HttpResponse response = stoScratchSupport.isEnabled()
            ? (HttpResponse) stoScratchSupport.invoke(
                  'barn',
                  new Map<String, Object>{ 'parentIdent' => parent.CRM_Person__r?.Name }
              )
            : NKS_ForeldreansvarService.barn(parent.CRM_Person__r?.Name);
        Map<String, Barn> lookup = new Map<String, Barn>();
        Boolean hasInvalidChildren = false;
        if (response.getStatusCode() != 204 && response.getStatusCode() != 404) {
            if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
                throw invalidResponse();
            }
            Object body;
            try {
                body = JSON.deserializeUntyped(response.getBody());
            } catch (System.JSONException error) {
                throw invalidResponse();
            }
            if (!(body instanceof Map<String, Object>)) {
                throw invalidResponse();
            }
            Object children = ((Map<String, Object>) body).get('barn');
            if (!(children instanceof List<Object>)) {
                throw invalidResponse();
            }
            for (Object rawChild : (List<Object>) children) {
                if (!(rawChild instanceof Map<String, Object>)) {
                    hasInvalidChildren = true;
                    continue;
                }
                Barn child;
                try {
                    child = (Barn) JSON.deserialize(JSON.serialize(rawChild), Barn.class);
                } catch (System.JSONException error) {
                    hasInvalidChildren = true;
                    continue;
                }
                if (
                    String.isBlank(child.ident) ||
                    String.isBlank(child.fornavn) ||
                    String.isBlank(child.etternavn) ||
                    child.alder == null ||
                    child.alder < 0
                ) {
                    hasInvalidChildren = true;
                    continue;
                }
                lookup.put(child.ident, child);
            }
        }
        if (hasInvalidChildren) {
            LoggerUtility logger = new LoggerUtility('Foreldreansvar');
            logger.error(
                'Ufullstendige opplysninger om barn fra nks-foreldreansvar',
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
            logger.publish();
        }
        childrenByUser.put(actorId, lookup);
        return lookup;
    }

    private static Account authenticatedParent() {
        Id accountId = currentUser().AccountId;
        if (accountId == null) {
            return null;
        }
        List<Account> parents = [
            SELECT CRM_Person__r.Name
            FROM Account
            WHERE Id = :accountId AND IsPersonAccount = TRUE
        ];
        return parents.isEmpty() ? null : parents[0];
    }

    private static AuraHandledException invalidVerificationResponse() {
        LoggerUtility logger = new LoggerUtility('Foreldreansvar');
        logger.error('Ugyldig svar ved verifisering av foreldreansvar', null, CRM_ApplicationDomain.Domain.NKS);
        logger.publish();
        return new AuraHandledException('Kunne ikke verifisere foreldreansvar. Prøv igjen senere.');
    }

    private static AuraHandledException invalidResponse() {
        LoggerUtility logger = new LoggerUtility('Foreldreansvar');
        logger.error('Ugyldig svar ved henting av barn fra nks-foreldreansvar', null, CRM_ApplicationDomain.Domain.NKS);
        logger.publish();
        return new AuraHandledException('Kunne ikke hente barn du kan representere. Prøv igjen senere.');
    }

    private class Barn {
        public String ident;
        public String fornavn;
        public String etternavn;
        public Integer alder;
    }

    public class PersonOption implements Comparable {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Id value;
        @AuraEnabled
        public String representedPersonIdentifier;

        private PersonOption(Id accountId, Barn child) {
            label = child.fornavn.trim() + ' ' + child.etternavn.trim() + ' (' + child.alder + ' år)';
            value = accountId;
            representedPersonIdentifier = child.ident;
        }

        public Integer compareTo(Object other) {
            return label.compareTo(((PersonOption) other).label);
        }

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

public with sharing class stoPersonContext {
    private static Map<Id, Set<String>> childIdentsByUser = new Map<Id, Set<String>>();

    @AuraEnabled(cacheable=true)
    public static List<PersonOption> getRepresentableChildren() {
        List<PersonOption> options = new List<PersonOption>();
        for (Account child : authorizedChildren()) {
            options.add(new PersonOption(child));
        }
        return options;
    }

    public static Boolean verifyRepresentation(String representedPersonIdentifier) {
        Account parent = authenticatedParent();
        if (parent == null) {
            return false;
        }
        HttpResponse response = NKS_ForeldreansvarService.verifiser(
            parent.CRM_Person__r?.Name,
            representedPersonIdentifier
        );
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
        HttpResponse response = NKS_ForeldreansvarService.barn(parent.CRM_Person__r?.Name);
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
        Id accountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
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

    private class BarnResponse {
        public List<Barn> barn;
    }

    private class Barn {
        public String ident;
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
                Date birthDate = Date.valueOf(birthDateValue);
                Integer age = Date.today().year() - birthDate.year();
                if (birthDate.addYears(age) > Date.today()) {
                    age--;
                }
                label += ' (' + age + ' år)';
            }
            value = child.Id;
            representedPersonIdentifier = child.CRM_Person__r?.Name;
        }
    }
}

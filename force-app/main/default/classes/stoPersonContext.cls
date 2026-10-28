public with sharing class stoPersonContext {
    @TestVisible
    private static List<Account> testChildren;

    // Cache only within this transaction, separately for each authenticated actor.
    private static Map<Id, Set<String>> childIdentsByUser = new Map<Id, Set<String>>();
    private static Map<String, Boolean> verificationByUserAndChild = new Map<String, Boolean>();

    // Scratch sharing/setup fixture only; never used to authorize representation.
    public static Map<String, Set<String>> scratchFamily() {
        return new Map<String, Set<String>>{
            '12345678901' => new Set<String>{ '12345678904', '12345678905' },
            '12345678902' => new Set<String>{ '12345678904', '12345678905' },
            '12345678903' => new Set<String>{ '12345678904' }
        };
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
        Id ownAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
        if (representedAccountId == null || representedAccountId == ownAccountId) {
            return ownAccountId;
        }
        for (Account child : authorizedChildren()) {
            if (child.Id == representedAccountId) {
                return child.Id;
            }
        }
        throw new AuraHandledException('Du har ikke tilgang til denne personens innboks.');
    }

    public static Id resolveContactId(Id authorizedAccountId) {
        Id ownAccountId = [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;
        if (authorizedAccountId == ownAccountId) {
            return [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId;
        }
        for (Account child : authorizedChildren()) {
            if (child.Id == authorizedAccountId) {
                return child.PersonContactId;
            }
        }
        throw new AuraHandledException('Du har ikke tilgang til denne personens innboks.');
    }

    public static Boolean verifyRepresentation(Id representedAccountId) {
        Id actorId = UserInfo.getUserId();
        String key = actorId + ':' + representedAccountId;
        if (verificationByUserAndChild.containsKey(key)) {
            return verificationByUserAndChild.get(key);
        }
        Id ownAccountId = [SELECT AccountId FROM User WHERE Id = :actorId].AccountId;
        if (representedAccountId == null || representedAccountId == ownAccountId) {
            return true;
        }
        resolveAccountId(representedAccountId);
        if (Test.isRunningTest() && testChildren != null) {
            return true;
        }
        Set<Id> accountIds = new Set<Id>{ ownAccountId, representedAccountId };
        Map<Id, Account> accounts = new Map<Id, Account>(
            [SELECT INT_PersonIdent__c FROM Account WHERE Id IN :accountIds]
        );
        HttpResponse response = NKS_ForeldreansvarService.verifiser(
            accounts.get(ownAccountId).INT_PersonIdent__c,
            accounts.get(representedAccountId).INT_PersonIdent__c
        );
        if (response.getStatusCode() == 204 || response.getStatusCode() == 404) {
            verificationByUserAndChild.put(key, false);
            return false;
        }
        if (response.getStatusCode() != 200 || String.isBlank(response.getBody())) {
            throw invalidResponse();
        }
        VerificationResponse body;
        try {
            body = (VerificationResponse) JSON.deserialize(response.getBody(), VerificationResponse.class);
        } catch (System.JSONException error) {
            throw invalidResponse();
        }
        if (body == null || body.kanRepresentere == null) {
            throw invalidResponse();
        }
        verificationByUserAndChild.put(key, body.kanRepresentere);
        return body.kanRepresentere;
    }

    private class VerificationResponse {
        public Boolean kanRepresentere;
    }

    private static List<Account> authorizedChildren() {
        if (Test.isRunningTest() && testChildren != null) {
            return testChildren;
        }
        Set<String> childIdents = verifiedChildIdents();
        if (childIdents.isEmpty()) {
            return new List<Account>();
        }
        // PersonHandler stores birth dates as ISO strings, not Account.PersonBirthdate.
        String adultBirthDate = String.valueOf(Date.today().addYears(-18));
        String today = String.valueOf(Date.today());
        return [
            SELECT Id, Name, PersonContactId, INT_PersonIdent__c, CRM_Person__r.INT_DateOfBirth__c
            FROM Account
            WHERE
                IsPersonAccount = TRUE
                AND INT_PersonIdent__c IN :childIdents
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
        Id actorAccountId = [SELECT AccountId FROM User WHERE Id = :actorId].AccountId;
        if (actorAccountId == null) {
            return new Set<String>();
        }
        List<Account> parents = [
            SELECT INT_PersonIdent__c
            FROM Account
            WHERE Id = :actorAccountId AND IsPersonAccount = TRUE
        ];
        if (parents.isEmpty()) {
            return new Set<String>();
        }
        HttpResponse response = NKS_ForeldreansvarService.barn(parents[0].INT_PersonIdent__c);
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

    private static AuraHandledException invalidResponse() {
        LoggerUtility logger = new LoggerUtility('Foreldreansvar');
        logger.error('Ugyldig svar fra nks-foreldreansvar', null, CRM_ApplicationDomain.Domain.NKS);
        logger.publish();
        return new AuraHandledException('Kunne ikke kontrollere hvilke barn du kan representere. Prøv igjen senere.');
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
        }
    }
}

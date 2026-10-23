// TODO(backend-ready): KEEP this resolver/DTO and server-side account validation; REPLACE only the scratch provider below.
public with sharing class stoPersonContext {
    // TODO(backend-ready): KEEP this test-only seam for isolated ownership tests; never use it for runtime authorization.
    @TestVisible
    private static List<Account> testChildren;

    // TODO(backend-ready): REMOVE this synthetic Foreldreansvar map with the scratch provider.
    // Far and Mor have felles ansvar; Medmor has Foreldreansvar for Beate only.
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

    private static List<Account> authorizedChildren() {
        if (Test.isRunningTest() && testChildren != null) {
            return testChildren;
        }
        // TODO(backend-ready): REPLACE the entire scratch gate/identity queries below with verified foreldreansvar.
        // REMOVE the fixture permission/identity grants together; preserve with sharing and fail-closed authorization.
        // Only the existing, explicitly configured scratch family is supported until
        // a production foreldreansvar source is available. Sandbox status alone is not authorization.
        // TODO(backend-ready): Use crm-community-base's scratch-domain gate; citizen licenses cannot query Organization.
        if (
            !URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com') ||
            !FeatureManagement.checkPermission('STO_Scratch_Family')
        ) {
            return new List<Account>();
        }
        User actor = [
            SELECT AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        // TODO(backend-ready): Query the actor's Account directly; citizen User.Account/Profile joins are restricted.
        if (actor.AccountId == null) {
            return new List<Account>();
        }
        // TODO(backend-ready): The scratch parent profile explicitly grants read access to this synthetic identity field.
        List<Account> fixtureParent = [
            SELECT Id, INT_PersonIdent__c
            FROM Account
            WHERE Id = :actor.AccountId AND IsPersonAccount = TRUE
        ];
        if (fixtureParent.isEmpty()) {
            return new List<Account>();
        }
        Set<String> childIdents = scratchFamily().get(fixtureParent[0].INT_PersonIdent__c);
        if (childIdents == null) {
            return new List<Account>();
        }
        // PersonHandler stores these fixture birth dates as ISO date strings, not Account.PersonBirthdate.
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

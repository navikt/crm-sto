// Tests shared child-selection labels and identity mapping without records or live service calls.
@isTest
public with sharing class stoPersonContextTest {
    @isTest
    static void personOptionAgeTest() {
        Map<Date, Integer> expectedAges = new Map<Date, Integer>{
            Date.today().addYears(-8).addDays(1) => 7,
            Date.today().addYears(-8) => 8,
            Date.today().addYears(-8).addDays(-1) => 8
        };
        for (Date birthDate : expectedAges.keySet()) {
            Account child = new Account(
                Id = '001000000000001AAA',
                Name = 'Barn',
                INT_PersonIdent__c = '12345678910',
                CRM_Person__r = new Person__c(INT_DateOfBirth__c = String.valueOf(birthDate))
            );
            stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

            Assert.areEqual('Barn (' + expectedAges.get(birthDate) + ' år)', option.label);
            Assert.areEqual(child.Id, option.value);
            Assert.areEqual(child.INT_PersonIdent__c, option.representedPersonIdentifier);
        }
    }

    @isTest
    static void personOptionWithoutBirthDateTest() {
        Account child = new Account(Id = '001000000000001AAA', Name = 'Barn', INT_PersonIdent__c = '12345678910');
        stoPersonContext.PersonOption option = new stoPersonContext.PersonOption(child);

        Assert.areEqual('Barn', option.label);
        Assert.areEqual(child.Id, option.value);
        Assert.areEqual(child.INT_PersonIdent__c, option.representedPersonIdentifier);
    }
}

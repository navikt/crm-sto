public with sharing class stoForeldreansvarMock {
    private static Map<String, Set<String>> cachedFamily;

    public static Boolean isEnabled() {
        if (!URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com')) {
            return false;
        }
        API_Controller_Mock_Settings__c setting = API_Controller_Mock_Settings__c.getValues(UserInfo.getUserId());
        if (setting == null) {
            setting = API_Controller_Mock_Settings__c.getValues(UserInfo.getProfileId());
        }
        return setting?.Use_Mock__c == true && setting.Status_Code__c == '200';
    }

    public static Map<String, Set<String>> family() {
        if (cachedFamily == null) {
            StaticResource fixture = [
                SELECT Body
                FROM StaticResource
                WHERE Name = 'STO_Foreldreansvar_Family'
                LIMIT 1
            ];
            Map<String, List<String>> data = (Map<String, List<String>>) JSON.deserialize(
                fixture.Body.toString(),
                Map<String, List<String>>.class
            );
            Map<String, Set<String>> family = new Map<String, Set<String>>();
            for (String parentIdent : data.keySet()) {
                family.put(parentIdent, new Set<String>(data.get(parentIdent)));
            }
            cachedFamily = family;
        }
        return cachedFamily;
    }

    public static HttpResponse barn(String parentIdent) {
        List<Object> children = new List<Object>();
        Set<String> childIdents = family().get(parentIdent);
        if (childIdents != null) {
            for (String childIdent : childIdents) {
                children.add(new Map<String, Object>{ 'ident' => childIdent });
            }
        }
        return response(new Map<String, Object>{ 'barn' => children });
    }

    public static HttpResponse verifiser(String parentIdent, String childIdent) {
        Set<String> childIdents = family().get(parentIdent);
        return response(
            new Map<String, Object>{ 'kanRepresentere' => childIdents != null && childIdents.contains(childIdent) }
        );
    }

    private static HttpResponse response(Map<String, Object> body) {
        if (!isEnabled()) {
            throw new MockDisabledException('Foreldreansvar-mock krever en scratch org med aktivert mockstatus 200.');
        }
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setHeader('Content-Type', 'application/json');
        response.setBody(JSON.serialize(body));
        return response;
    }

    public class MockDisabledException extends Exception {
    }
}

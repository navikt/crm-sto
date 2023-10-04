public with sharing class NKS_NavUnitLinks {
    @AuraEnabled(cacheable=true)
    public static List<NavLinks> getNavLinks() {
        Http h = new Http();

        // Instantiate a new HTTP request, specify the method (GET) as well as the endpoint
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.nav.no/_/service/no.nav.navno/officeInfo');
        req.setMethod('GET');

        // Send the request, and return a response
        HttpResponse res = h.send(req);
        String navUnitsJson = res.getBody();
        NavResponse retUnits = (NavResponse) JSON.deserialize(navUnitsJson, NavResponse.class);
        return retUnits.offices;
    }

    public class NavResponse {
        public List<NavLinks> offices;
    }

    public class NavLinks {
        @AuraEnabled
        public String path;
        @AuraEnabled
        public String enhetNr;
    }
}

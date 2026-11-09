public with sharing class stoScratchSupport {
    public static Boolean isEnabled() {
        return URL.getOrgDomainUrl().getHost().endsWithIgnoreCase('.scratch.my.salesforce.com') &&
            FeatureManagement.checkPermission('STO_Scratch_Fixtures');
    }

    public static Object invoke(String action, Map<String, Object> arguments) {
        if (!isEnabled()) {
            throw new AuraHandledException('Scratch fixtures require a scratch org and STO_Scratch_Fixtures.');
        }
        // Scratch metadata is excluded from production CI, so there is no compile-time dependency on it.
        Type adapter = Type.forName('stoScratchFixtures');
        if (adapter == null) {
            throw new AuraHandledException('Deploy force-app/scratch-org/classes before enabling scratch fixtures.');
        }
        return ((System.Callable) adapter.newInstance()).call(action, arguments);
    }
}

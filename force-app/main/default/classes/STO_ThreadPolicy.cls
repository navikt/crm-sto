public without sharing class STO_ThreadPolicy {
    public static final Integer MAX_THREAD_COUNT_STO = 3;
    public static final Integer MAX_THREAD_COUNT_BTO = 10;
    public static final Integer MAX_MESSAGE_LENGTH = 2000;
    private static final Map<String, List<String>> THREAD_TYPES = new Map<String, List<String>>{
        'STO' => new List<String>{ 'STO', 'STB' },
        'BTO' => new List<String>{ 'BTO' },
        'ALL' => new List<String>{ 'STO', 'STB', 'BTO' }
    };

    public static String creationType(String threadType) {
        if (String.isBlank(threadType)) {
            return 'STO';
        }
        if (threadType != 'STO' && threadType != 'BTO') {
            throw new stoHelperClass.InvalidThreadDataException('Unsupported thread type.');
        }
        return threadType;
    }

    public static List<String> getThreadTypes(String threadType) {
        String key = String.isBlank(threadType) ? 'ALL' : threadType;
        if (!THREAD_TYPES.containsKey(key)) {
            throw new stoHelperClass.InvalidThreadDataException('Unsupported thread type.');
        }
        return THREAD_TYPES.get(key);
    }

    public static Integer maxThreadCount(String threadType) {
        return creationType(threadType) == 'BTO' ? MAX_THREAD_COUNT_BTO : MAX_THREAD_COUNT_STO;
    }

    public static String validateCategory(String category) {
        if (String.isNotBlank(category)) {
            for (Schema.PicklistEntry entry : Thread__c.STO_Category__c.getDescribe().getPicklistValues()) {
                if (entry.isActive() && entry.getValue().equalsIgnoreCase(category)) {
                    return entry.getValue();
                }
            }
        }
        throw new stoHelperClass.InvalidThreadDataException('A supported thread category is required.');
    }

    public static void lockAccount(Id accountId) {
        List<Account> accounts = [SELECT Id FROM Account WHERE Id = :accountId FOR UPDATE];
        if (accounts.isEmpty()) {
            throw new stoHelperClass.NoAccountFoundException('Thread account was not found.');
        }
    }

    public static Integer countOpenThreads(Id accountId, String category, String threadType) {
        List<String> types = getThreadTypes(threadType);
        return [
            SELECT COUNT()
            FROM Thread__c
            WHERE
                CRM_Account__c = :accountId
                AND STO_Category__c = :category
                AND CRM_Thread_Type__c IN :types
                AND CRM_Is_Closed__c = FALSE
                AND Id IN (SELECT CRM_Thread__c FROM Message__c WHERE CRM_Type__c IN ('Message', 'Info'))
        ];
    }

    public static Boolean hasCategoryAtLimit(Id accountId) {
        List<String> types = getThreadTypes('STO');
        return ![
                SELECT STO_Category__c, COUNT(Id)
                FROM Thread__c
                WHERE
                    CRM_Account__c = :accountId
                    AND CRM_Thread_Type__c IN :types
                    AND CRM_Is_Closed__c = FALSE
                    AND Id IN (SELECT CRM_Thread__c FROM Message__c WHERE CRM_Type__c IN ('Message', 'Info'))
                GROUP BY STO_Category__c
                HAVING COUNT(Id) >= :MAX_THREAD_COUNT_STO
                LIMIT 1
            ]
            .isEmpty();
    }
}

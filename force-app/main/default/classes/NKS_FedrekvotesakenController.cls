public without sharing class NKS_FedrekvotesakenController {
    private static LoggerUtility logger = new LoggerUtility('Fedrekvotesaken');
    /*
        tasktype: Vurder konsekvens for ytelse
        Tema: Foreldre- og svangerskapspenger
        Gjelder: Fedrekvote
        Prioritet: Lav
        Enhet: 4863 NAV Familie og pensjonsytelser midlertidig enhet

        taskteksten skal vises som følger:

        Barnets navn: Navn Navnesen
        Fødselsdato: 01-01-2000
        Bruker hatt permisjon med barnet?
        Ja - Fikk du dekket lønn av arbeidsgiver under permisjonen? - Ja/Nei

        Delvis - Tidsrom: Fra dato - til dato
        Fikk du dekket lønn av arbeidsgiver under permisjonen? - Ja/Nei

        Nei - Gjennomfør vurdering av brukers situasjon

        Brukers telefonnummer: XXXXXXXX
    */

    /*
    let fedrekvoteData = {
        children: [
            {
                name: 'Johnny Bravo',
                birthdate: 'fint formatert dato hehe',
                leave: {
                    type: 'Yes/Partly/No',
                    salary: 'Yes/No',
                    dates: {
                        fromDate: 'fint formatert dato hehe',
                        toDate: 'fint formatert dato hehe'
                    }
                }
            },
        ],
        phone: '12345678'
    };
    */

    @AuraEnabled
    public static Id createNavTask(String jsonData) {
        Fedrekvote fedrekvoteData = (Fedrekvote) JSON.deserialize(jsonData, Fedrekvote.class);
        if (fedrekvoteData == null) {
            logger.error('Fedrekvotedata from LWC was null.', null, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
            return '';
        }

        User personUser = getAccountAndContactId();
        Common_Code__c commonCode = getThemeAndSubTheme();
        NavUnit__c navUnit = getNavUnit();

        NavTask__c task = new NavTask__c();
        task.Name = 'Vurder henvendelse';
        task.CRM_NoPersonInformation__c = false;
        task.CRM_Account__c = personUser?.AccountId;
        task.NKS_Theme__c = commonCode?.CRM_Parent_Code__c;
        task.NKS_TaskType__c = getType();
        task.CRM_Priority__c = 'LAV';
        task.NKS_Subtheme__c = commonCode?.CRM_Subtheme__c;
        task.CRM_NavUnit__c = navUnit?.Id;
        task.NKS_Comments__c = formatComment(fedrekvoteData);
        task.OwnerId = UserInfo.getUserId();
        task.NKS_Experience_Site_Source__c = 'Fedrekvotesaken';

        Thread__c thread;
        try {
            Map<String, Object> flowInputs = new Map<String, Object>{ 'NAV_Task' => task };
            Flow.Interview flow = Flow.Interview.createInterview('CRM_Send_NAV_Task_Auto', flowInputs);
            flow.start();

            thread = createSTBThread(task.Id, personUser, navUnit.INT_UnitNumber__c, commonCode.CRM_Parent_Code__c);
            createMessage(thread, task.NKS_Comments__c);
        } catch (Exception e) {
            System.debug('createNavTask error: ' + e.getMessage());
            logger.error('Failed to insert task: ' + e.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
            throw new FedrekvoteException(e);
        } finally {
            logger.publish();
        }
        return thread?.Id;
    }

    public static String formatComment(Fedrekvote fedrekvoteData) {
        String comment = '';
        Map<String, String> englishToNorwegianMap = new Map<String, String>{
            'yes' => 'Ja',
            'no' => 'Nei',
            'partly' => 'Delvis'
        };

        for (Child child : fedrekvoteData.children) {
            comment +=
                'Barnets navn: ' +
                child.name +
                '\n' +
                'Fødselsdato: ' +
                child.birthdate +
                '\n' +
                'Bruker hatt permisjon med barnet? - ' +
                englishToNorwegianMap.get(child.leave.type.toLowerCase()) +
                '\n';

            if (child.leave.type == 'Yes') {
                comment +=
                    'Fikk du dekket lønn av arbeidsgiver under permisjonen? - ' +
                    englishToNorwegianMap.get(child.leave.salary.toLowerCase()) +
                    '\n';
            } else if (child.leave.type == 'Partly') {
                comment += 'Tidsrom: ' + child.leave.dates.fromDate + ' - ' + child.leave.dates.toDate + '\n';
                comment +=
                    'Fikk du dekket lønn av arbeidsgiver under permisjonen? - ' +
                    englishToNorwegianMap.get(child.leave.salary.toLowerCase()) +
                    '\n';
            } else {
                comment += 'Gjennomfør vurdering av brukers situasjon' + '\n';
            }
            comment += '\n';
        }
        comment += 'Brukers telefonnummer: ' + fedrekvoteData.phone;
        return comment;
    }

    // Max create 1 NavTask per user. Filter on createddate as extra security.
    @AuraEnabled
    public static Boolean hasExistingNavTasks() {
        Id accountId = getAccountAndContactId()?.AccountId;
        Id navUnit = getNavUnit()?.Id;
        List<NavTask__c> existingNavTasks = [
            SELECT Id
            FROM NavTask__c
            WHERE CRM_Account__c = :accountId AND CreatedDate > 2024-03-15T00:00:00Z AND CRM_NavUnit__c = :navUnit AND NKS_Experience_Site_Source__c = 'Fedrekvotesaken'
        ];
        return existingNavTasks.size() > 0;
    }

    private static NavUnit__c getNavUnit() {
        return [SELECT Id, INT_UnitNumber__c FROM NavUnit__c WHERE INT_UnitNumber__c = '4863' LIMIT 1];
    }

    private static Id getType() {
        return [SELECT Id FROM Common_Code__c WHERE Name = 'Vurder henvendelse' LIMIT 1]?.Id;
    }

    private static Common_Code__c getThemeAndSubTheme() {
        return [
            SELECT Id, CRM_Subtheme__c, CRM_Parent_Code__c
            FROM Common_Code__c
            WHERE Name = 'Fedrekvote' AND CRM_Code_Set__c = 'Gjelder'
            LIMIT 1
        ];
    }

    private static User getAccountAndContactId() {
        return [SELECT AccountId, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    }

    private static Thread__c createSTBThread(String relatedObjId, User personUser, String unitNumber, Id theme) {
        Id themeGroup = [
            SELECT Id
            FROM Common_Code__c
            WHERE CRM_Code_Set__c = 'Temagrupper' AND CRM_Code__c = 'FMLI'
            LIMIT 1
        ]
        ?.Id;

        Thread__c thread = new Thread__c();
        thread.CRM_Related_Object__c = relatedObjId;
        thread.CRM_Contact__c = personUser?.ContactId;
        thread.CRM_Account__c = personUser?.AccountId;
        thread.CRM_Created_By_NAV_Unit__c = unitNumber;
        thread.CRM_Theme_Group__c = themeGroup; // Familie
        thread.CRM_Theme__c = theme; // Foreldre- og svangerskapspenger
        thread.Name = 'Skriv til bruker';
        thread.CRM_Thread_Type__c = 'STB';
        thread.CRM_isActive__c = false;
        thread.CRM_Closed_Date__c = Datetime.now();
        thread.NKS_Experience_Site_Source__c = 'Fedrekvotesaken';

        try {
            insert thread;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
        }
        return thread;
    }

    private static void createMessage(Thread__c thread, String comments) {
        Message__c message = new Message__c();
        message.CRM_Message_Text__c = 'Takk for informasjonen vedrørende Fedrekvotesaken. Vi tar kontakt hvis vi trenger flere opplysninger fra deg.';
        message.CRM_From_NAV_Unit__c = thread.CRM_Created_By_NAV_Unit__c;
        message.CRM_Thread__c = thread.Id;

        String modifiedComments = comments.replace('Bruker hatt', 'Har du hatt').replace('Brukers', 'Ditt');

        Integer indexToRemove = comments.indexOf('Gjennomfør vurdering av brukers situasjon');
        if (indexToRemove != -1) {
            Integer newlineIndex = comments.indexOf('\n', indexToRemove);
            if (newlineIndex != -1) {
                modifiedComments =
                    modifiedComments.substring(0, indexToRemove) + modifiedComments.substring(newlineIndex + 1);
            } else {
                modifiedComments = modifiedComments.remove('Gjennomfør vurdering av brukers situasjon');
            }
        }
        message.CRM_Message_Text__c += '\n\nDu har oppgitt følgende informasjon: \n\n' + modifiedComments;

        try {
            insert message;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
        }
    }

    public class Fedrekvote {
        public List<Child> children;
        public String phone;
    }

    public class Child {
        public String name;
        public String birthdate;
        public Leave leave;
    }

    public class Leave {
        public String type;
        public String salary;
        public Dates dates;
    }

    public class Dates {
        public String fromDate;
        public String toDate;
    }

    public class FedrekvoteException extends Exception {
    }
}

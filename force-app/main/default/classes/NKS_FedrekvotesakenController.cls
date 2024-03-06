public with sharing class NKS_FedrekvotesakenController {
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

    // TODO: Remember to add permissions for fields to experience site users
    @AuraEnabled
    public static void createNavTask(String jsonData) {
        Fedrekvote fedrekvoteData = (Fedrekvote) JSON.deserialize(jsonData, Fedrekvote.class);

        try {
            NavTask__c task = new NavTask__c();
            task.Name = 'Vurder konsekvens for ytelse';
            task.CRM_NoPersonInformation__c = true; // TODO: Need this?
            task.CRM_Account__c = UserInfo.getUserId();
            task.NKS_Theme__c = getTheme();
            task.NKS_Theme_Group__c = null; // TODO: Need this?
            task.NKS_Henvendelse_BehandlingsId__c = null; // TODO: Need this?
            task.NKS_Assignee__c = null; // TODO: Need this?
            task.NKS_TaskType__c = getType();
            task.CRM_Subtype__c = null; // TODO: Need this?
            task.CRM_Priority__c = 'LAV';
            task.NKS_Subtheme__c = getSubThemeGjelder();
            task.CRM_NavUnit__c = getNavUnitId();
            task.NKS_Comments__c = formatComment(fedrekvoteData);
            task.OwnerId = UserInfo.getUserId(); // TODO: Set owner to user? In that case we need to share the navtasks with the experience site user where accountid matches their id

            insert task;

            Map<String, Object> flowInputs = new Map<String, Object>{
                'NAV_Task' => task,
                'Created_By_Unit_Number' => '4106' // TODO: What unit number to set? (NAV Kontaktsenter Oslo og Vest-Viken currently)
            };
            Flow.Interview flow = Flow.Interview.createInterview('CRM_Send_NAV_Task_Auto', flowInputs);
            flow.start();
        } catch (Exception e) {
            System.debug('createNavTask error: ' + e.getMessage());
            throw new FedrekvoteException(e);
        }
    }

    public static String formatComment(Fedrekvote fedrekvoteData) {
        String comment = '';
        Map<String, String> englishToNorwegianMap = new Map<String, String>{
            'Yes' => 'Ja',
            'No' => 'Nei',
            'Partly' => 'Delvis'
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
                englishToNorwegianMap.get(child.leave.type) +
                '\n';

            if (child.leave.type == 'Yes') {
                comment +=
                    'Fikk du dekket lønn av arbeidsgiver under permisjonen? - ' +
                    englishToNorwegianMap.get(child.leave.salary) +
                    '\n';
            } else if (child.leave.type == 'Partly') {
                comment += 'Tidsrom: ' + child.leave.dates.fromDate + ' - ' + child.leave.dates.toDate + '\n';
                comment +=
                    'Fikk du dekket lønn av arbeidsgiver under permisjonen? - ' +
                    englishToNorwegianMap.get(child.leave.salary) +
                    '\n';
            } else {
                comment += 'Gjennomfør vurdering av brukers situasjon' + '\n';
            }
            comment += 'Brukers telefonnummer: ' + fedrekvoteData.phone + '\n\n';
        }
        return comment;
    }

    // TODO: Share all nav tasks with accountid = UserInfo.getUserId(), otherwise this query will return 0 results always
    // Max 1 NavTask per user
    @AuraEnabled
    public static Boolean hasExistingNavTasks() {
        List<NavTask__c> existingNavTasks = [SELECT Id FROM NavTask__c WHERE CRM_Account__c = :UserInfo.getUserId()];
        return existingNavTasks.size() > 0;
    }

    private static Id getNavUnitId() {
        return [SELECT Id FROM NavUnit__c WHERE INT_UnitNumber__c = '4863' LIMIT 1]?.Id;
    }

    private static Id getType() {
        return [SELECT Id FROM Common_Code__c WHERE Name = 'Vurder konsekvens for ytelse' LIMIT 1]?.Id;
    }

    private static Id getSubThemeGjelder() {
        return [SELECT Id FROM Common_Code__c WHERE Name = 'Fedrekvote' AND CRM_Code_Set__c = 'Behandlingstema' LIMIT 1]
        ?.Id;
    }

    private static Id getTheme() {
        return [
            SELECT Id
            FROM Common_Code__c
            WHERE Name = 'Foreldre- og svangerskapspenger' AND CRM_Code_Set__c = 'Tema'
            LIMIT 1
        ]
        ?.Id;
    }

    public class FedrekvoteException extends Exception {
    }
}

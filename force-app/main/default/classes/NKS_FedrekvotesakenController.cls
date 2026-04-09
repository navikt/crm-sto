public without sharing class NKS_FedrekvotesakenController {
    private static LoggerUtility logger = new LoggerUtility('Fedrekvotesaken');

    private static User userRecord {
        get {
            if (userRecord == null) {
                userRecord = [SELECT AccountId, ContactId, CRM_Person__r.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            }
            return userRecord;
        }
        set {
        }
    }

    @AuraEnabled
    public static void postTask(String jsonData) {
        if (hasExistingNavTasks()) {
            logger.error(
                'User already has exsisting Nav task related to fedrekvotesaken',
                null,
                CRM_ApplicationDomain.Domain.NKS
            );
            logger.publish();
            return '';
        }

        Fedrekvote fedrekvoteData = (Fedrekvote) JSON.deserialize(jsonData, Fedrekvote.class);
        if (fedrekvoteData == null) {
            logger.error('Fedrekvotedata from LWC was null.', null, CRM_ApplicationDomain.Domain.NKS);
            logger.publish();
            return '';
        }

        Common_Code__c commonCode = getThemeAndSubTheme();
        String beskrivelse = formatBeskrivelse(fedrekvoteData);

        OppgaveManager.OppgaveRequest taskRequest = new OppgaveManager.OppgaveRequest();
        taskRequest.tildeltEnhetsnr = '4863';
        taskRequest.aktoerId = userRecord?.CRM_Person__r?.Name;
        taskRequest.oppgavetype = 'VURD_HENV';
        taskRequest.tema = commonCode?.CRM_Parent_Code__r?.CRM_Code__c;
        taskRequest.behandlingstema = commonCode?.CRM_Subtheme__r?.CRM_Code__c;
        taskRequest.prioritet = 'LAV';
        taskRequest.beskrivelse = beskrivelse;

        try {
            Oppgave oppgave = OppgaveManager.postTask(taskRequest);
            // TODO: Create record to retry posting on fail - NKS-1969
            if (oppgave == null || oppgave.id == null) {
                throw new FedrekvoteException('Failed to create oppgave via API');
            }

            Thread__c thread = createSTBThread(commonCode.CRM_Parent_Code__c);
            createMessage(thread, beskrivelse);
        } catch (Exception e) {
            logger.error('Failed to post task: ' + e.getMessage(), null, CRM_ApplicationDomain.Domain.NKS);
            throw new FedrekvoteException(e);
        } finally {
            logger.publish();
        }
    }

    public static String formatBeskrivelse(Fedrekvote fedrekvoteData) {
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

            if (child.leave.type == 'Yes' || child.leave.type == 'Partly') {
                comment += 'Tidsrom: ' + child.leave.dates.fromDate + ' - ' + child.leave.dates.toDate + '\n';
                comment +=
                    'Fikk du dekket lønn av arbeidsgiver under permisjonen? - ' +
                    englishToNorwegianMap.get(child.leave.salary.toLowerCase()) +
                    '\n';
            }
            comment += '\n';
        }
        comment += 'Brukers telefonnummer: ' + fedrekvoteData.phone;
        return comment;
    }

    // TODO: Query oppgave to see if existing task for Fedrekvotesaken exists
    @AuraEnabled
    public static Boolean hasExistingNavTasks() {
        return false;
    }

    private static Common_Code__c getThemeAndSubTheme() {
        return [
            SELECT Id, CRM_Parent_Code__c, CRM_Subtheme__r.CRM_Code__c, CRM_Parent_Code__r.CRM_Code__c
            FROM Common_Code__c
            WHERE Name = 'Fedrekvote' AND CRM_Code_Set__c = 'Gjelder'
            LIMIT 1
        ];
    }

    private static Thread__c createSTBThread(Id theme) {
        Id themeGroup = [
            SELECT Id
            FROM Common_Code__c
            WHERE CRM_Code_Set__c = 'Temagrupper' AND CRM_Code__c = 'FMLI'
            LIMIT 1
        ]
        ?.Id;

        Thread__c thread = new Thread__c();
        thread.CRM_Contact__c = userRecord?.ContactId;
        thread.CRM_Account__c = userRecord?.AccountId;
        thread.CRM_Created_By_NAV_Unit__c = '4863';
        thread.CRM_Theme_Group__c = themeGroup; // Familie
        thread.CRM_Theme__c = theme; // Foreldre- og svangerskapspenger
        thread.Name = 'Skriv til bruker';
        thread.CRM_Thread_Type__c = 'STB';
        thread.NKS_Experience_Site_Source__c = 'Fedrekvotesaken';

        try {
            insert thread;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
        } finally {
            // Set closed/isactive after insert to ensure correct order of operations.
            // We do not want to close/set to inactive before other functionality has finished running.
            thread.CRM_isActive__c = false;
            thread.CRM_Closed_Date__c = Datetime.now();
            update thread;
        }
        return thread;
    }

    private static void createMessage(Thread__c thread, String beskrivelse) {
        Message__c message = new Message__c();
        message.CRM_Message_Text__c = 'Takk for informasjonen vedrørende Fedrekvotesaken. Vi tar kontakt hvis vi trenger flere opplysninger fra deg. Vi behandler mottatte henvendelser så raskt vi kan, og vi forventer at alle får svar i løpet av 2025.';
        message.CRM_From_NAV_Unit__c = thread.CRM_Created_By_NAV_Unit__c;
        message.CRM_Thread__c = thread.Id;

        String modifiedbeskrivelse = beskrivelse.replace('Bruker hatt', 'Har du hatt').replace('Brukers', 'Ditt');
        message.CRM_Message_Text__c += '\n\nDu har oppgitt følgende informasjon: \n\n' + modifiedbeskrivelse;

        try {
            insert message;
        } catch (DmlException e) {
            logger.exception(e, CRM_ApplicationDomain.Domain.NKS);
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

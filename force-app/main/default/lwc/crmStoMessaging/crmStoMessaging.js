import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import getThreadId from '@salesforce/apex/STO_RecordInfoController.getThreadIdByApiReference';
import NKS_FULL_NAME from '@salesforce/schema/User.NKS_FullName__c';
import COMPANY_NAME from '@salesforce/schema/User.CompanyName';
import PERSON_FULL_NAME from '@salesforce/schema/Person__c.NKS_Full_Name__c';
import CASE_THREAD_API_REFERENCE from '@salesforce/schema/Case.NKS_Henvendelse_BehandlingsId__c';
import THREAD_MEDSKRIV_REFERENCE from '@salesforce/schema/Thread__c.STO_Medskriv__C';
import THREAD_TYPE from '@salesforce/schema/Thread__c.CRM_Thread_Type__c';
import MEDSKRIV_TEXT from '@salesforce/label/c.STO_Medskriv_Text';
import MEDSKRIV_LABEL from '@salesforce/label/c.STO_Medskriv_Label';
import userId from '@salesforce/user/Id';
import newDesignTemplate from './newDesignTemplate.html';
import oldDesignTemplate from './oldDesignTemplate.html';

const englishCompanyTranslations = {
    'DIR Ytelsesavdelingen': 'Benefits department, Directorate of Labour and Welfare',
    'NAV Arbeid og ytelser styringsenhet': 'NAV Work and Benefits Management Unit',
    'NAV Familie- og pensjonsytelser': 'NAV Family Benefits and Pensions Management Unit',
    'NAV Kontroll Øst': 'NAV Control Eastern Norway',
    'NAV Kontroll Vest': 'NAV Control Western Norway',
    'NAV Kontroll Nord': 'NAV Control Northern Norway',
    'NAV Kontroll Styringsenhet': 'NAV Control Management Unit',
    'NAV Medlemskap og avgift': 'NAV Social insurance and Contributions',
    'NAV Oppfølging utland': 'Norwegian Labour and rehabilitation unit',
    'NAV Registerforvaltning': 'NAV Registry Management',
    'NAV Styringsenhet Kontaktsenter': 'NAV Call and Service Centre Management Unit',
    'Seksjon fag- og ytelsesutvikling': 'Pensions and benefits - Legislation and development',
    'Seksjon informasjonsforvaltning': 'Information Management',
    'Seksjon juridisk': 'Legal affairs',
    'Seksjon kompetanseutvikling': 'Professional Development',
    'Seksjon styring': 'Governance',
    Ytelseslinjen: 'NAV Benefits Administration'
};

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;
    @api cardTitle;
    @api showClose = false;
    @api checkMedskriv = false;
    @api newDesign = false;
    @api submitButtonLabel;

    wireField;
    accountId;
    userId;
    personId;
    userName;
    supervisorName;
    companyName;
    norwegianCompanyName;
    englishCompanyName;
    accountApiName;
    threadId;
    englishTextTemplate = false;
    acceptedMedskriv = false;
    medskriv = false;
    threadType;

    labels = {
        MEDSKRIV_TEXT,
        MEDSKRIV_LABEL
    };

    render() {
        return this.newDesign ? newDesignTemplate : oldDesignTemplate;
    }

    connectedCallback() {
        if (!this.newDesign) {
            this.template.addEventListener('toolbaraction', (event) => {
                let flowInputs = [];
                //logic to validate and create correct flowInputs for the flow to be triggered
                switch (event.detail.flowName) {
                    case 'CRM_Case_Journal_STO_Thread':
                        flowInputs = [
                            {
                                name: 'Thread_ID',
                                type: 'String',
                                value: event.threadId
                            }
                        ];
                        //Adding the flowInputs parameters to the event
                        event.detail.flowInputs = flowInputs;
                        break;
                    case 'CRM_STO_transfer':
                        flowInputs = [
                            {
                                name: 'recordId',
                                type: 'String',
                                value: this.recordId
                            },
                            {
                                name: 'Thread_ID',
                                type: 'String',
                                value: event.threadId
                            }
                        ];
                        break;
                    default:
                        break;
                }
                //Adding the flowInputs parameters to the event
                event.detail.flowInputs = flowInputs;

                this.dispatchStoToolbarAction(event); //Forwards the event to parent
            });
        }
        this.wireField =
            this.objectApiName === 'Case'
                ? [this.objectApiName + '.Id', CASE_THREAD_API_REFERENCE]
                : [this.objectApiName + '.Id'];
        this.userId = userId;
        this.accountApiName = this.getAccountApiName();
    }

    dispatchStoToolbarAction(event) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('sto_toolbaraction', event);

        this.dispatchEvent(toolbarActionEvent);
    }

    getNorwegianCompanyName() {
        try {
            // Return all "Kontaktsenter"-units as "NAV Kontaktsenter"
            if (
                this.companyName.toLowerCase().includes('kontaktsenter') &&
                !this.companyName.toLowerCase().toLowerCase().includes('styringsenhet')
            ) {
                return 'NAV Kontaktsenter';
            }
            const startWords = ['DIR', 'HJELPEMIDDEL', 'NAV', 'SEKSJON', 'YTELSE'];
            const words = [
                'Analyse',
                'Avgift',
                'Helse',
                'Pensjonsytelser',
                'Styringsavdelingen',
                'Styringsenhet',
                'Tjenesteavdelingen',
                'Ytelser',
                'Ytelsesutvikling'
            ];
            // Check for related units
            if (startWords.some((str) => this.companyName.startsWith(str))) {
                let listString = this.companyName.toLowerCase().split(' ');
                for (let i = 0; i < listString.length; i++) {
                    if (listString[i].length > 1) {
                        listString[i] = listString[i].charAt(0).toUpperCase() + listString[i].slice(1).toLowerCase();
                        if (listString[i].toUpperCase() === 'NAV' || listString[i].toUpperCase() === 'DIR') {
                            listString[i] = listString[i].toUpperCase();
                        } else if (
                            (i > 0 && listString[i - 1].toUpperCase() === 'SEKSJON') ||
                            listString[i].toUpperCase() === 'OG' ||
                            (((i > 0 && listString[i - 1].toUpperCase() === 'OG') ||
                                (i > 1 && listString[i - 2].toUpperCase() === 'OG')) &&
                                words.includes(listString[i]))
                        ) {
                            listString[i] = listString[i].toLowerCase();
                        } else if (listString[i].includes('-') || listString[i].includes('/')) {
                            listString[i] = listString[i].replaceAll(/[-/][a-z]/g, (match) => match.toUpperCase());
                        }
                    }
                }
                return listString.join(' ');
            }
            return this.companyName;
        } catch (error) {
            console.log('Problem getting Norwegian company name: ' + error);
            return '';
        }
    }

    getEnglishCompanyName() {
        try {
            // English translation for management units
            if (this.norwegianCompanyName in englishCompanyTranslations) {
                return englishCompanyTranslations[this.norwegianCompanyName];
            }
            let ecn = '';
            let hasEnglishTranslation = true;
            const mapObj = {
                og: 'and',
                i: 'in'
            };
            const unitsWithPrepositions = [
                'NAV Eiganes og Tasta',
                'NAV Evje og Hornnes',
                'NAV Herøy og Vanylven',
                'NAV Hillevåg og Hinna',
                'NAV Hundvåg og Storhaug',
                'NAV Møre og Romsdal',
                'NAV Nes i Akershus',
                'NAV Oppdal og Rennebu',
                'NAV Rennesøy og Finnøy',
                'NAV Røros, Os og Holtålen',
                'NAV Troms og Finnmark',
                'NAV Vestfold og Telemark',
                'NAV Våler i Hedmark'
                //'NAV Øst i Agder'
            ];

            if (this.norwegianCompanyName.includes('Arbeid og ytelser')) {
                ecn = this.norwegianCompanyName.replace('Arbeid og ytelser', 'Work and Benefits');
            } else if (this.norwegianCompanyName.includes('Familie- og pensjonsytelser')) {
                ecn = this.norwegianCompanyName.replace('Familie- og pensjonsytelser', 'Family Benefits and Pensions');
            } else if (this.norwegianCompanyName.includes('Hjelpemiddelsentral')) {
                ecn = this.norwegianCompanyName.replace('Hjelpemiddelsentral', 'Department of assistive technology');
            } else if (this.norwegianCompanyName.includes('Klageinstans')) {
                ecn = this.norwegianCompanyName.replace('Klageinstans', 'Appeals');
            } else if (this.norwegianCompanyName.includes('Kontaktsenter')) {
                ecn = this.norwegianCompanyName.replace('Kontaktsenter', 'Call and Service Center');
            } else if (this.norwegianCompanyName.includes('Kontroll Analyse')) {
                ecn = this.norwegianCompanyName.replace('Kontroll Analyse', 'Control Analysis');
            } else if (this.norwegianCompanyName.includes('Kontroll')) {
                ecn = this.norwegianCompanyName.replace('Kontroll', 'Control');
            } else if (this.norwegianCompanyName.includes('Tiltak')) {
                ecn = this.norwegianCompanyName.replace('Tiltak', 'Department for employment measures');
            } else if (this.norwegianCompanyName.includes('Ytelseslinjen')) {
                ecn = this.norwegianCompanyName.replace('Ytelseslinjen', 'Benefits Administration');
            } else {
                if (unitsWithPrepositions.includes(this.norwegianCompanyName)) {
                    ecn = this.norwegianCompanyName.replace(/\b(?:og|i)\b/gi, (matched) => mapObj[matched]);
                    return ecn;
                }
                hasEnglishTranslation = false;
                console.log('There is no translation for this CompanyName.');
                return this.norwegianCompanyName;
            }
            if (hasEnglishTranslation) {
                ecn = ecn.replace(/\b(?:og|i)\b/gi, (matched) => mapObj[matched]);
            }
            return ecn;
        } catch (error) {
            console.log('Problem getting English company name: ' + error);
            return '';
        }
    }

    get textTemplate() {
        let salutation = this.userName == null ? 'Hei,' : 'Hei, ' + this.userName;
        let regards = 'Med vennlig hilsen';

        if (this.englishTextTemplate === true) {
            salutation = this.userName == null ? 'Hi,' : 'Hi ' + this.userName + ',';
            regards = 'Kind regards';
        }

        return `${salutation}\n\n\n\n${regards}\n${this.supervisorName}\n${
            this.englishTextTemplate === true ? this.englishCompanyName : this.norwegianCompanyName
        }`;
    }

    get computeClasses() {
        return this.threadType === 'BTO' ? 'greenHeader' : '';
    }

    get actualCardTitle() {
        if (this.objectApiName === 'Case' && ['BTO', 'STO'].includes(this.threadType))
            return this.threadType === 'STO' ? 'Skriv til oss' : 'Beskjed til oss';

        return this.cardTitle;
    }

    get showMedskrivBlocker() {
        return this.checkMedskriv === true && this.acceptedMedskriv === false && this.medskriv === false;
    }

    getAccountApiName() {
        if (this.objectApiName === 'Case') {
            return 'AccountId';
        } else if (this.objectApiName === 'Thread__c') {
            return 'CRM_Account__c';
        }
        console.log('Something is wrong with Account API name');
        return null;
    }

    getAccountId() {
        getRelatedRecord({
            parentId: this.recordId,
            relationshipField: this.accountApiName,
            objectApiName: this.objectApiName
        })
            .then((record) => {
                this.accountId = this.resolve(this.accountApiName, record);
            })
            .catch((error) => {
                console.log(error);
            });
    }

    getPersonId() {
        getRelatedRecord({
            parentId: this.accountId,
            relationshipField: 'CRM_Person__c',
            objectApiName: 'Account'
        })
            .then((record) => {
                this.personId = this.resolve('CRM_Person__c', record);
            })
            .catch((error) => {
                console.log('Problem getting person id: ', error);
            });
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$wireField'
    })
    wiredRecord({ error, data }) {
        if (error) {
            console.log('problem getting record: ', error);
        } else if (data) {
            if (this.objectApiName === 'Case') {
                let ThreadApiReference = getFieldValue(data, CASE_THREAD_API_REFERENCE);
                this.getThreadId(ThreadApiReference);
            } else if (this.objectApiName === 'Thread__c') {
                this.threadId = this.recordId;
            }
            this.getAccountId();
        }
    }

    getThreadId(apiRef) {
        getThreadId({ apiRef: apiRef })
            .then((threadId) => {
                this.threadId = threadId;
            })
            .catch((error) => {
                console.log('Problem getting thread id: ', error);
            });
    }

    @wire(getRecord, {
        recordId: '$accountId',
        fields: ['Account.Id']
    })
    wiredAccount({ error, data }) {
        if (error) {
            console.log('Problem getting account: ', error);
        } else if (data) {
            if (this.accountId) {
                this.getPersonId();
            }
        }
    }

    @wire(getRecord, {
        recordId: '$personId',
        fields: [PERSON_FULL_NAME]
    })
    wiredPerson({ error, data }) {
        if (error) {
            console.log('Problem getting person', error);
        } else if (data) {
            if (this.accountId && this.personId) {
                let fullName = getFieldValue(data, PERSON_FULL_NAME);
                this.userName = fullName ? fullName.split(' ').shift() : '';
            }
        }
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: [NKS_FULL_NAME, COMPANY_NAME]
    })
    wiredUser({ error, data }) {
        if (error) {
            console.log('Problem getting user: ', error);
        } else if (data) {
            this.supervisorName = getFieldValue(data, NKS_FULL_NAME);
            this.companyName = getFieldValue(data, COMPANY_NAME);
            try {
                this.norwegianCompanyName = this.getNorwegianCompanyName();
                this.englishCompanyName = this.getEnglishCompanyName();
            } catch (error2) {
                console.log('Problem getting company name: ', error2);
            }
        }
    }

    @wire(getRecord, { recordId: '$threadId', fields: [THREAD_MEDSKRIV_REFERENCE, THREAD_TYPE] })
    wiredThread({ error, data }) {
        if (error) {
            console.log('Medskriv error: ', error);
        }
        if (data) {
            this.medskriv = getFieldValue(data, THREAD_MEDSKRIV_REFERENCE);
            this.threadType = getFieldValue(data, THREAD_TYPE);
        }
    }

    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj);
    }

    handleEnglishEventTwo(event) {
        this.englishTextTemplate = event.detail;
    }

    handleMedskrivClick() {
        this.acceptedMedskriv = true;
        const child = this.template.querySelector('c-crm-messaging-message-component');
        child.checkSlotChange('messages');
        child.focus();
    }

    handleSubmit() {
        this.dispatchEvent(new CustomEvent('submitfromparent'));
    }
}

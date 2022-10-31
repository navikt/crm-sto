import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import getThreadId from '@salesforce/apex/STO_RecordInfoController.getThreadIdByApiReference';
import NKS_FULL_NAME from '@salesforce/schema/User.NKS_FullName__c';
import COMPANY_NAME from '@salesforce/schema/User.CompanyName';
import PERSON_FULL_NAME from '@salesforce/schema/Person__c.NKS_Full_Name__c';
import CASE_THREAD_API_REFERENCE from '@salesforce/schema/Case.NKS_Henvendelse_BehandlingsId__c';
import userId from '@salesforce/user/Id';

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;
    @api cardTitle;
    @api showClose = false;
    @api checkMedskriv;
    acceptedMedskriv;

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

    connectedCallback() {
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
            } else {
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
                    for (var i = 0; i < listString.length; i++) {
                        if (listString[i].length > 1) {
                            listString[i] =
                                listString[i].charAt(0).toUpperCase() + listString[i].slice(1).toLowerCase();
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
                                listString[i] = listString[i].replaceAll(/[\-\/][a-z]/g, (match) =>
                                    match.toUpperCase()
                                );
                            }
                        }
                    }
                    // console.log(listString.join(' '));
                    return listString.join(' ');
                } else {
                    return this.companyName;
                }
            }
        } catch (error) {
            console.log('Problem getting Norwegian company name: ' + error);
            return '';
        }
    }

    getEnglishCompanyName() {
        try {
            // English translation for management units
            switch (this.norwegianCompanyName) {
                case 'DIR Ytelsesavdelingen':
                    return 'Benefits department, Directorate of Labour and Welfare';

                case 'NAV Arbeid og ytelser styringsenhet':
                    return 'NAV Work and Benefits Management Unit';

                case 'NAV Familie- og pensjonsytelser':
                    return 'NAV Family Benefits and Pensions Management Unit';

                case 'NAV Kontroll Øst':
                    return 'NAV Control Eastern Norway';

                case 'NAV Kontroll Vest':
                    return 'NAV Control Western Norway';

                case 'NAV Kontroll Nord':
                    return 'NAV Control Northern Norway';

                case 'NAV Kontroll Styringsenhet':
                    return 'NAV Control Management Unit';

                case 'NAV Medlemskap og avgift':
                    return 'NAV Social insurance and Contributions';

                case 'NAV Registerforvaltning':
                    return 'NAV Registry Management';

                case 'NAV Styringsenhet Kontaktsenter':
                    return 'NAV Call and Service Centre Management Unit';

                case 'Seksjon fag- og ytelsesutvikling':
                    return 'Pensions and benefits - Legislation and development';

                case 'Seksjon informasjonsforvaltning':
                    return 'Information Management';

                case 'Seksjon juridisk':
                    return 'Legal affairs';

                case 'Seksjon kompetanseutvikling':
                    return 'Professional Development';

                case 'Seksjon styring':
                    return 'Governance';

                case 'Ytelseslinjen':
                    return 'NAV Benefits Administration';

                // English translation for related units
                default:
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
                        ecn = this.norwegianCompanyName.replace(
                            'Familie- og pensjonsytelser',
                            'Family Benefits and Pensions'
                        );
                    } else if (this.norwegianCompanyName.includes('Hjelpemiddelsentral')) {
                        ecn = this.norwegianCompanyName.replace(
                            'Hjelpemiddelsentral',
                            'Department of assistive technology'
                        );
                    } else if (this.norwegianCompanyName.includes('Klageinstans')) {
                        ecn = this.norwegianCompanyName.replace('Klageinstans', 'Appeals');
                    } else if (this.norwegianCompanyName.includes('Kontaktsenter')) {
                        ecn = this.norwegianCompanyName.replace('Kontaktsenter', 'Call and Service Center');
                    } else if (this.norwegianCompanyName.includes('Kontroll Analyse')) {
                        ecn = this.norwegianCompanyName.replace('Kontroll Analyse', 'Control Analysis');
                    } else if (this.norwegianCompanyName.includes('Kontroll')) {
                        ecn = this.norwegianCompanyName.replace('Kontroll', 'Control');
                    } else if (this.norwegianCompanyName.includes('Ytelseslinjen')) {
                        ecn = this.norwegianCompanyName.replace('Ytelseslinjen', 'Benefits Administration');
                    } else {
                        if (unitsWithPrepositions.includes(this.norwegianCompanyName)) {
                            ecn = this.norwegianCompanyName.replace(/\b(?:og|i)\b/gi, (matched) => mapObj[matched]);
                            return ecn;
                        } else {
                            hasEnglishTranslation = false;
                            console.log('There is no translation for this CompanyName.');
                            return this.norwegianCompanyName;
                        }
                    }
                    if (hasEnglishTranslation) {
                        ecn = ecn.replace(/\b(?:og|i)\b/gi, (matched) => mapObj[matched]);
                    }
                    return ecn;
            }
        } catch (error) {
            console.log('Problem getting English company name: ' + error);
            return '';
        }
    }

    get textTemplate() {
        let salutation = this.userName == null ? 'Hei,' : 'Hei ' + this.userName + ',';
        let regards = 'Med vennlig hilsen';

        if (this.englishTextTemplate === true) {
            salutation = this.userName == null ? 'Hi,' : 'Hi ' + this.userName + ',';
            regards = 'Kind regards';
        }

        return `${salutation}\n\n\n${regards}\n${this.supervisorName}\n${
            this.englishTextTemplate === true ? this.englishCompanyName : this.norwegianCompanyName
        }`;
    }

    get threadReference() {
        return this.threadId ? this.threadId : this.recordId;
    }

    getAccountApiName() {
        if (this.objectApiName === 'Case') {
            return 'AccountId';
        } else if (this.objectApiName === 'Thread__c') {
            return 'CRM_Account__c';
        } else {
            console.log('Something is wrong with Account API name');
        }
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
                console.log(error);
            });
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$wireField'
    })
    wiredRecord({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            if (this.objectApiName === 'Case') {
                let ThreadApiReference = getFieldValue(data, CASE_THREAD_API_REFERENCE);
                this.getThreadId(ThreadApiReference);
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
                //Failure yields rollback to using record id as reference
            });
    }

    @wire(getRecord, {
        recordId: '$accountId',
        fields: ['Account.Id']
    })
    wiredAccount({ error, data }) {
        if (error) {
            console.log(error);
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
            console.log(error);
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
            console.log(error);
        } else if (data) {
            this.supervisorName = getFieldValue(data, NKS_FULL_NAME);
            this.companyName = getFieldValue(data, COMPANY_NAME);
            try {
                this.norwegianCompanyName = this.getNorwegianCompanyName();
                this.englishCompanyName = this.getEnglishCompanyName();
            } catch (error) {
                console.log(error);
            }
        }
    }

    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj || self);
    }

    handleEnglishEventTwo(event) {
        this.englishTextTemplate = event.detail;
    }

    handleMedskrivClick() {
        this.renderSlotContent = true;
    }

    fakeMedskrivField = true;

    get showMedskrivBlocker() {
        // return this.checkMedskriv === true && this.acceptedMedskriv === false && this.thread.STO_Medskriv__c === false;
        return this.checkMedskriv === true && this.acceptedMedskriv === false && this.fakeMedskrivField === false;
    }

    renderSlotContent = true;

    handleClick() {
        this.renderSlotContent = !this.renderSlotContent;
        const child = this.template.querySelector('c-crm-messaging-message-component');
        child.checkSlotChange();
    }
}

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
        const cities = ['Finnmark', 'Romsdal', 'Telemark'];
        const startWords = ['NAV', 'DIR', 'SEKSJON', 'YTELSE', 'HJELPEMIDDEL'];
        if (startWords.some((str) => this.companyName.startsWith(str))) {
            let listString = this.companyName.toLowerCase().split(' ');
            for (var i = 0; i < listString.length; i++) {
                listString[i] = listString[i].charAt(0).toUpperCase() + listString[i].slice(1).toLowerCase();
                if (listString[i].toUpperCase() === 'NAV' || listString[i].toUpperCase() === 'DIR') {
                    listString[i] = listString[i].toUpperCase();
                } else if (
                    (i > 0 && listString[i - 1].toUpperCase() === 'SEKSJON') ||
                    listString[i].toUpperCase() === 'OG' ||
                    (i > 0 && listString[i - 1].toUpperCase() === 'OG' && !cities.includes(listString[i])) ||
                    (i > 1 && listString[i - 2].toUpperCase() === 'OG' && listString[i] === 'Styringsenhet') ||
                    listString[i] === 'Analyse'
                ) {
                    listString[i] = listString[i].toLowerCase();
                } else if (listString[i].includes('-')) {
                    var index = listString[i].indexOf('-');
                    listString[i] =
                        listString[i].slice(0, index + 1) +
                        listString[i].charAt(index + 1).toUpperCase() +
                        listString[i].slice(index + 2);
                }
            }
            //console.log(listString.join(' '));
            return listString.join(' ');
        } else {
            return this.companyName;
        }
    }

    getEnglishCompanyName() {
        let ecn = '';
        let hasEnglishTranslation = true;

        // managements
        if (this.norwegianCompanyName === 'DIR Ytelsesavdelingen') {
            ecn = 'Benefits department, Directorate of Labour and Welfare';
        }
        if (this.norwegianCompanyName === 'Ytelseslinjen') {
            ecn = 'NAV Benefits Administration';
        } else if (this.norwegianCompanyName === 'NAV Arbeid og ytelser styringsenhet') {
            ecn = 'NAV Work and Benefits Management Unit';
        } else if (this.norwegianCompanyName === 'NAV Familie- og pensjonsytelser') {
            ecn = 'NAV Family Benefits and Pensions Management Unit';
        } else if (this.norwegianCompanyName === 'NAV Kontroll Styringsenhet') {
            ecn = 'NAV Control Management Unit';
        } else if (this.norwegianCompanyName === 'NAV Registerforvaltning') {
            ecn = 'NAV Registry Management';
        } else if (this.norwegianCompanyName === 'NAV Medlemskap og avgift') {
            ecn = 'NAV Social insurance and Contributions';
        }

        // sections
        else if (this.norwegianCompanyName === 'Seksjon informasjonsforvaltning') {
            ecn = 'Information Management';
        } else if (this.norwegianCompanyName === 'Seksjon styring') {
            ecn = 'Governance';
        } else if (this.norwegianCompanyName === 'Seksjon kompetanseutvikling') {
            ecn = 'Professional Development';
        } else if (this.norwegianCompanyName === 'Seksjon juridisk') {
            ecn = 'Legal affairs';
        } else if (this.norwegianCompanyName === 'Seksjon fag- og ytelsesutvikling') {
            ecn = 'Pensions and benefits - Legislation and development';

            // units
        } else if (this.norwegianCompanyName.includes('Kontaktsenter')) {
            ecn = this.norwegianCompanyName.replace('Kontaktsenter', 'Call and Service Center');
        } else if (this.norwegianCompanyName.includes('Hjelpemiddelsentral')) {
            ecn = this.norwegianCompanyName.replace('Hjelpemiddelsentral', 'Department of assistive technology');
        } else if (this.norwegianCompanyName.includes('Ytelseslinjen')) {
            ecn = this.norwegianCompanyName.replace('Ytelseslinjen', 'Benefits Administration');
        } else if (this.norwegianCompanyName.includes('Arbeid og ytelser')) {
            ecn = this.norwegianCompanyName.replace('Arbeid og ytelser', 'Work and Benefits');
        } else if (this.norwegianCompanyName.includes('Familie- og pensjonsytelser')) {
            ecn = this.norwegianCompanyName.replace('Familie- og pensjonsytelser', 'Family Benefits and Pensions');
        } else if (this.norwegianCompanyName.includes('Kontroll analyse')) {
            ecn = this.norwegianCompanyName.replace('Kontroll analyse', 'Control Analysis');
        } else if (this.norwegianCompanyName.includes('Kontroll')) {
            ecn = this.norwegianCompanyName.replace('Kontroll', 'Control');
        } else {
            hasEnglishTranslation = false;
            console.log('There is no translation for this CompanyName.');
            return this.norwegianCompanyName;
        }
        if (hasEnglishTranslation) {
            if (ecn.includes('og')) {
                ecn = ecn.replaceAll('og', 'and');
            }
        }
        return ecn;
    }

    get textTemplate() {
        if (this.englishTextTemplate == true) {
            let greeting = '';
            greeting = this.userName == null ? 'Hi,' : 'Hi ' + this.userName + ',';
            return greeting + '\n\n\nKind regards\n' + this.supervisorName + '\n' + this.englishCompanyName;
        }
        let greeting = '';
        greeting = this.userName == null ? 'Hei,' : 'Hei ' + this.userName + ',';
        return greeting + '\n\n\nMed vennlig hilsen\n' + this.supervisorName + '\n' + this.norwegianCompanyName;
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
}

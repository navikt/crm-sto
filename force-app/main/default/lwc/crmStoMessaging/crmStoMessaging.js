import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import getThreadId from '@salesforce/apex/STO_RecordInfoController.getThreadIdByApiReference';
import NKS_FULL_NAME from '@salesforce/schema/User.NKS_FullName__c';
import FIRST_NAME from '@salesforce/schema/Person__c.INT_FirstName__c';
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

    get textTemplate() {
        if (this.englishTextTemplate == true) {
            let greeting = '';
            greeting = this.userName == null ? 'Hi,' : 'Hi ' + this.userName + ',';
            return greeting + '\n\n\nKind regards\n' + this.supervisorName + '\nNAV Contact center';
        }
        let greeting = '';
        greeting = this.userName == null ? 'Hei,' : 'Hei ' + this.userName + ',';
        return greeting + '\n\n\nMed vennlig hilsen\n' + this.supervisorName + '\nNAV Kontaktsenter';
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
        fields: [FIRST_NAME]
    })
    wiredPerson({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            if (this.accountId && this.personId) {
                let list = [];
                let firstName = getFieldValue(data, FIRST_NAME).toLowerCase().split(' ');
                firstName.forEach((item) => list.push(item.charAt(0).toUpperCase() + item.slice(1)));
                this.userName = list.join(' ');
            }
        }
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: [NKS_FULL_NAME]
    })
    wiredUser({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            this.supervisorName = getFieldValue(data, NKS_FULL_NAME);
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

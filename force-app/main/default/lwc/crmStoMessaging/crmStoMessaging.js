import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import NKS_FullName from '@salesforce/schema/User.NKS_FullName__c';
import NAME from '@salesforce/schema/Account.Name';
import userId from '@salesforce/user/Id';

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;
    @api cardTitle;

    wireField;
    userId;
    accountId;
    userName;
    supervisorName;
    accountApiName;
    account = 'Account';

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
        this.wireField = [this.objectApiName + '.Id'];
        this.userId = userId;
        this.accountApiName = this.getAccountApiName();
    }

    dispatchStoToolbarAction(event) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('sto_toolbaraction', event);

        this.dispatchEvent(toolbarActionEvent);
    }

    get textTemplate() {
        return 'Hei ' + this.userName + ',\n\n\nMed vennlig hilsen\n' + this.supervisorName + '\nNAV Kontaktsenter';
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$wireField'
    })
    wiredRecord({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            this.getAccountId();
        }
    }

    @wire(getRecord, {
        recordId: '$accountId',
        fields: [NAME]
    })
    wiredPerson({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            let fullName = getFieldValue(data, NAME);
            this.userName = fullName.split(' ')[0];
        }
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: [NKS_FullName]
    })
    wiredUser({ error, data }) {
        if (error) {
            console.log(error);
        } else if (data) {
            this.supervisorName = getFieldValue(data, NKS_FullName);
        }
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

    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj || self);
    }
}

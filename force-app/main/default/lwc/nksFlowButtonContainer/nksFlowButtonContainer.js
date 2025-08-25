import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import ISCLOSED_FIELD from '@salesforce/schema/Case.IsClosed';
import CASE_ORIGIN_FIELD from '@salesforce/schema/Case.NKS_Case_Origin__c';

export default class NksFlowButtonContainer extends LightningElement {
    @api recordId;

    wiredCase;
    status;
    closed;
    caseOrigin;

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, ISCLOSED_FIELD, CASE_ORIGIN_FIELD] })
    wiredRecord(result) {
        this.wiredCase = result;
        const { data, error } = result;
        if (data) {
            this.status = getFieldValue(data, STATUS_FIELD);
            this.closed = getFieldValue(data, ISCLOSED_FIELD);
            this.caseOrigin = getFieldValue(data, CASE_ORIGIN_FIELD);
        } else if (error) {
            console.log(error.body.message);
        }
    }

    flowFinishHandler() {
        refreshApex(this.wiredCase);
    }

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    get completeDisabled() {
        return this.status !== 'In progress' && this.status !== 'Reserved';
    }

    get reserveDisabled() {
        return this.status !== 'In progress' || this.closed === true;
    }

    get putBackDisabled() {
        return this.status === 'Forwarded' || this.closed === true;
    }

    get isNotBTO() {
        return this.caseOrigin !== 'BTO';
    }

    get sldsSize() {
        return this.caseOrigin !== 'BTO' ? 'slds-size_6-of-12' : 'slds-size_12-of-12';
    }
}

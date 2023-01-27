import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import ISCLOSED_FIELD from '@salesforce/schema/Case.IsClosed';

export default class NksFlowButtonContainer extends LightningElement {
    @api recordId;

    wiredCase;
    status;
    closed;

    connectedCallback() {}

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, ISCLOSED_FIELD] })
    wiredRecord(result) {
        this.wiredCase = result;
        const { data, error } = result;
        if (data) {
            this.status = getFieldValue(data, STATUS_FIELD);
            this.closed = getFieldValue(data, ISCLOSED_FIELD);
        } else if (error) {
            console.log(error.body.message);
        }
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

    get disabledComplete() {
        return this.status !== 'In progress' && this.status !== 'Reserved';
    }

    get disabledReserve() {
        return this.status !== 'In progress' || this.closed === true;
    }

    get disabledPutBack() {
        return this.status === 'Forwarded' || this.closed === true;
    }
}

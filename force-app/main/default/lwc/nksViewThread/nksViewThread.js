import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import THREAD_TYPE from '@salesforce/schema/Thread__c.CRM_Thread_Type__c';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import basepath from '@salesforce/community/basePath';

const urlMap = {
    STO: (recordId) => basepath + '/skriv-til-oss/' + recordId,
    STB: (recordId) => basepath + '/skriv-til-oss/' + recordId,
    BTO: (recordId) => basepath + '/beskjed-til-oss/visning?samtale=' + recordId
};

const allowedThreadTypes = {
    STO: ['STO', 'STB'],
    BTO: ['BTO']
};

export default class NksViewThread extends LightningElement {
    @api threadType;
    @api recordId;
    @api maxLength;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference?.state?.samtale != null) {
            this.recordId = currentPageReference.state.samtale;
        }
    }

    getField;
    @wire(getRecord, { recordId: '$recordId', fields: [THREAD_TYPE] })
    wiredThread({ error, data }) {
        if (error) {
            console.log('Error:', error);
        } else if (data) {
            const actualThreadType = getFieldValue(data, THREAD_TYPE);
            if (!allowedThreadTypes[this.threadType].includes(actualThreadType)) this.redirect(actualThreadType);
        }
    }

    // Redirect for static user notifications links
    redirect(actualThreadType) {
        const link = urlMap[actualThreadType](this.recordId);
        window.open(link, '_self');
    }
}

import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import THREAD_TYPE from '@salesforce/schema/Thread__c.CRM_Thread_Type__c';
import THREAD_EXTERNAL_NAME from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import basepath from '@salesforce/community/basePath';
import { getContentType } from 'c/stoUtils';
import { AnalyticsEvents, logButtonEvent } from 'c/inboxAmplitude';

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

    _recordId;
    threadExternalName;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference?.state?.samtale != null) {
            this._recordId = currentPageReference.state.samtale;
        } else {
            this._recordId = this.recordId;
        }
    }

    @wire(getRecord, { recordId: '$_recordId', fields: [THREAD_TYPE, THREAD_EXTERNAL_NAME] })
    wiredThread({ error, data }) {
        if (error) {
            console.log('Error:', error);
        } else if (data) {
            this.threadExternalName = getFieldValue(data, THREAD_EXTERNAL_NAME);
            const actualThreadType = getFieldValue(data, THREAD_TYPE);
            if (!allowedThreadTypes[this.threadType].includes(actualThreadType)) this.redirect(actualThreadType);
        }
    }

    // Redirect for static user notifications links
    redirect(actualThreadType) {
        const link = urlMap[actualThreadType](this._recordId);
        // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
        window.open(link, '_self');
    }

    logAmplitudeEvent() {
        logButtonEvent(
            AnalyticsEvents.FORM_COMPLETED,
            'Send',
            getContentType(this.threadExternalName),
            'nksViewThread',
            this.threadExternalName,
            'ny melding'
        );
    }
}

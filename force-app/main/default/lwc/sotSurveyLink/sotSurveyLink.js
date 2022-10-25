import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import THREADCLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
//import THREADTYPE_FIELD from '@saleforce/schema/Thread__c.CRM_Thread_Type__c';
import countSurveys from '@salesforce/apex/stoInboxHelper.countSurveyResponses';
import INFOLOGO from '@salesforce/resourceUrl/InformationLogoFilled';

const fields = [THREADCLOSED_FIELD];

export default class SotSurveyLink extends LightningElement {
    @api recordId;
    thread;
    logopath = INFOLOGO;

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredthread(result) {
        this.thread = result;
    }

    get limitExceeded() {
        const limit = countSurveys();
        return limit > 300 ? true : false;
    }

    get isclosed() {
        return getFieldValue(this.thread.data, THREADCLOSED_FIELD);
    }

    /*
    get type() {
        return getFieldValue(this.thread.data, THREADTYPE_FIELD);
    }*/

    get showOpenText() {
        return !this.isclosed ? true : false;
    }

    get showCloseText() {
        return this.isclosed ? true : false;
    }
}

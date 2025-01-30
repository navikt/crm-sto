import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import THREAD_IS_CLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';
import THREAD_RELATED_OBJECT_FIELD from '@salesforce/schema/Thread__c.CRM_Related_Object__c';
import THREAD_NAME_FIELD from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import getSurvey from '@salesforce/apex/STO_SurveyHelper.getSurveyLink';
import getURL from '@salesforce/apex/STO_SurveyHelper.getURL';
import checkResponse from '@salesforce/apex/STO_SurveyHelper.checkResponse';
import { logNavigationEvent } from 'c/amplitude';

export default class StoInboxInformation extends LightningElement {
    @api recordId;

    type;
    closed = false;
    caseId;
    url;
    surveyLink;
    completed = false;
    threadExternalName;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [THREAD_IS_CLOSED_FIELD, THREAD_TYPE_FIELD, THREAD_RELATED_OBJECT_FIELD]
    })
    wiredThread({ data, error }) {
        if (data) {
            this.type = getFieldValue(data, THREAD_TYPE_FIELD);
            this.closed = getFieldValue(data, THREAD_IS_CLOSED_FIELD);
            this.caseId = getFieldValue(data, THREAD_RELATED_OBJECT_FIELD);
            this.threadExternalName = getFieldValue(data, THREAD_NAME_FIELD);
        } else if (error) {
            console.log('Problem getting thread: ' + error);
        }
    }

    @wire(getSurvey, { caseId: '$caseId' })
    wiredLink({ data, error }) {
        if (data && this.caseId) {
            this.surveyLink = data;
        } else if (error) {
            console.log('Problem getting surveyLink: ' + error);
        }
    }

    connectedCallback() {
        getURL()
            .then((url) => {
                this.url = url;
            })
            .catch((error) => {
                console.log('Problem getting Base URL for Feedback Community: ' + JSON.stringify(error, null, 2));
            });
    }

    navigateToSurvey() {
        checkResponse({ caseId: this.caseId })
            .then((res) => {
                this.completed = res;
            })
            .catch((error) => {
                console.log('Problem checking ResponseStatus: +' + JSON.stringify(error, null, 2));
            })
            .finally(() => {
                if (this.completed) {
                    // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
                    window.open(this.url);
                } else {
                    // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
                    window.open(this.surveyLink);
                }
            });

        logNavigationEvent(
            'stoInboxInformation',
            this.threadExternalName,
            this.completed ? this.url : this.surveyLink,
            'Klikk her for å svare'
        );
    }

    get isClosedSTOorBTO() {
        return (this.type === 'STO' || this.type === 'BTO') && this.closed;
    }

    get infoText() {
        if (this.closed) {
            return this.type === 'BTO'
                ? 'Samtalen er avsluttet. Vil du <a href="https://www.nav.no/send-beskjed">sende en ny melding</a>, kan du gjøre det her.'
                : 'Samtalen er avsluttet. Vil du <a href="https://www.nav.no/person/kontakt-oss/nb/skriv-til-oss">sende en ny melding</a>, kan du gjøre det her.';
        }
        return 'Hvis du vil kan du svare på denne samtalen innen 7 dager. Samtalen avsluttes automatisk dersom du ikke har flere spørsmål, og lagres i din innboks.';
    }

    get showSurveyButton() {
        return this.type === 'STO' && this.closed && this.surveyLink !== null && this.surveyLink !== undefined;
    }
}

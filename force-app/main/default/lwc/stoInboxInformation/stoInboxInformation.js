import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import THREAD_IS_CLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';
import THREAD_RELATED_OBJECT_FIELD from '@salesforce/schema/Thread__c.CRM_Related_Object__c';
import getSurvey from '@salesforce/apex/STO_SurveyHelper.getSurveyLink';
import getURL from '@salesforce/apex/STO_SurveyHelper.getURL';
import checkResponse from '@salesforce/apex/STO_SurveyHelper.checkResponse';
import LoggerUtility from 'c/loggerUtility';

export default class StoInboxInformation extends LightningElement {
    type;
    closed = false;
    caseId;
    url;
    surveyLink;

    @api recordId;
    @track completed = false;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [THREAD_IS_CLOSED_FIELD, THREAD_TYPE_FIELD, THREAD_RELATED_OBJECT_FIELD]
    })
    wiredThread({ data, error }) {
        if (data) {
            this.type = getFieldValue(data, THREAD_TYPE_FIELD);
            this.closed = getFieldValue(data, THREAD_IS_CLOSED_FIELD);
            this.caseId = getFieldValue(data, THREAD_RELATED_OBJECT_FIELD);
        } else if (error) {
            LoggerUtility.logError(
                'NKS',
                'STO',
                error,
                'An error has occurred while trying to fetch Thread.',
                this.recordId
            );
        }
    }

    @wire(getSurvey, { caseId: '$caseId' })
    wiredLink({ data, error }) {
        if (data && this.caseId) {
            this.surveyLink = data;
        } else if (error) {
            LoggerUtility.logError(
                'NKS',
                'STO',
                error,
                'An error has occurred while trying to fetch SurveyLink.',
                this.recordId
            );
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
                    window.open(this.url);
                } else {
                    window.open(this.surveyLink);
                }
            });
    }

    get isClosedSTO() {
        return this.type === 'STO' && this.closed;
    }

    get infoText() {
        let retText = '';
        if (this.closed) {
            retText =
                'Samtalen er avsluttet. Vil du <a href="https://www.nav.no/person/kontakt-oss/nb/skriv-til-oss">sende en ny melding</a>, kan du gjøre det her.';
        } else {
            retText =
                'Hvis du vil kan du svare på denne samtalen innen 7 dager. Samtalen avsluttes automatisk dersom du ikke har flere spørsmål, og lagres i din innboks.';
        }

        return retText;
    }
}

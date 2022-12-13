import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import THREAD_IS_CLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';
import getSurvey from '@salesforce/apex/STO_SurveyHelper.getSurveyLink';

export default class StoInboxInformation extends LightningElement {
    @api recordId;

    surveyLink;
    isLoaded = false;

    connectedCallback() {
        getSurvey()
            .then((link) => {
                this.surveyLink = link;
            })
            .catch((error) => {
                //Error getting link;
            })
            .finally(() => {
                this.isLoaded = true;
            });
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [THREAD_IS_CLOSED_FIELD, THREAD_TYPE_FIELD]
    })
    threadRecord;

    navigateToSurvey() {
        window.open(this.surveyLink);
    }

    get isClosedSTO() {
        return (
            getFieldValue(this.threadRecord.data, THREAD_TYPE_FIELD) === 'STO' &&
            getFieldValue(this.threadRecord.data, THREAD_IS_CLOSED_FIELD) === true
        );
    }

    get infoText() {
        let retText;
        if (this.threadRecord) {
            if (getFieldValue(this.threadRecord.data, THREAD_IS_CLOSED_FIELD) === true) {
                retText =
                    'Samtalen er avsluttet. Vil du <a href="https://www.nav.no/person/kontakt-oss/nb/skriv-til-oss">sende en ny melding</a>, kan du gjøre det her.';
            } else {
                retText =
                    'Hvis du vil kan du svare på denne samtalen innen 7 dager. Samtalen avsluttes automatisk dersom du ikke har flere spørsmål, og lagres i din innboks.';
            }
        }
        return retText;
    }
}

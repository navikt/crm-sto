import { LightningElement, api, wire } from 'lwc';
import getSurvey from '@salesforce/apex/STO_SurveyHelper.getSurveyLink';
import getURL from '@salesforce/apex/STO_SurveyHelper.getURL';
import checkResponse from '@salesforce/apex/STO_SurveyHelper.checkResponse';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';
import { CurrentPageReference } from 'lightning/navigation';

export default class StoInboxInformation extends LightningElement {
    @api recordId;

    type;
    closed;
    caseId;
    url;
    surveyLink;
    completed = false;
    _recordId;

    connectedCallback() {
        getURL()
            .then((url) => {
                this.url = url;
            })
            .catch((error) => {
                console.error('Problem getting Base URL for Feedback Community: ' + JSON.stringify(error, null, 2));
            });
    }

    @wire(CurrentPageReference)
    async getStateParameters(currentPageReference) {
        const newRecordId = currentPageReference?.state?.samtale || this.recordId;
        if (newRecordId && newRecordId !== this._recordId) {
            this._recordId = newRecordId;
            await this.fetchThreadData();
        }
    }

    async fetchThreadData() {
        try {
            const data = await getThread({ recordId: this._recordId });
            if (data) {
                this.type = data.CRM_Thread_Type__c;
                this.closed = data.CRM_Is_Closed__c;
                this.caseId = data.CRM_Related_Object__c;
            }
        } catch (error) {
            console.error('Problem getting thread:', error);
        }
    }

    @wire(getSurvey, { caseId: '$caseId' })
    wiredLink({ data, error }) {
        if (data && this.caseId) {
            this.surveyLink = data;
        } else if (error) {
            console.error('Problem getting surveyLink: ' + error);
        }
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
            getComponentName(this.template),
            'undersøkelse',
            this.completed ? this.url : this.surveyLink,
            'Klikk her for å svare'
        );
    }

    get infoText() {
        return this.closed
            ? 'Samtalen er avsluttet. Vil du <a href="https://www.nav.no/skriv-til-oss" target="_self">sende en ny melding</a>, kan du gjøre det her.'
            : 'Du kan svare på denne samtalen innen syv dager. Samtalen avsluttes automatisk dersom du ikke har flere spørsmål, og lagres i din innboks.';
    }

    get showSurveyButton() {
        return this.type === 'STO' && this.closed && this.surveyLink !== null && this.surveyLink !== undefined;
    }
}

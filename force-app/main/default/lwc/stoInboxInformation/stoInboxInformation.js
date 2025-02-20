import { LightningElement, api, wire } from 'lwc';
import getSurvey from '@salesforce/apex/STO_SurveyHelper.getSurveyLink';
import getURL from '@salesforce/apex/STO_SurveyHelper.getURL';
import checkResponse from '@salesforce/apex/STO_SurveyHelper.checkResponse';
import { logNavigationEvent, getComponentName, setDecoratorParams } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

export default class StoInboxInformation extends LightningElement {
    @api recordId;

    type;
    closed = false;
    caseId;
    url;
    surveyLink;
    completed = false;

    @wire(getThread, { recordId: '$recordId' })
    wiredThread({ error, data }) {
        if (error) {
            console.error('Problem getting thread:', error);
        } else if (data) {
            this.type = data.CRM_Thread_Type__c;
            this.closed = data.CRM_Is_Closed__c;
            this.caseId = data.CRM_Related_Object__c;
            const pageTheme = data.NKS_Inbox_Theme__c;
            const pageType = data.NKS_Inbox_Type__c;

            if (pageType && pageTheme) {
                setDecoratorParams(pageType, pageTheme);
                // eslint-disable-next-line no-extra-boolean-cast
                let tabName = `${pageType}${!!!pageTheme ? '' : ' - ' + pageTheme}`;
                // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
                setTimeout(function () {
                    document.title = tabName;
                }, 1000);
            }
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
            getComponentName(this.template),
            'undersøkelse',
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

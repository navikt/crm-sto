import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import basepath from '@salesforce/community/basePath';
import { AnalyticsEvents, logButtonEvent, setDecoratorParams, getComponentName } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

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
    pageTheme;
    pageType;
    pageTitle;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.samtale != null) {
            this._recordId = currentPageReference.state.samtale;
        } else {
            this._recordId = this.recordId;
        }
    }

    @wire(getThread, { recordId: '$_recordId' })
    wiredThread({ error, data }) {
        if (error) {
            console.error('Problem getting thread:', error);
        } else if (data) {
            const actualThreadType = data.CRM_Thread_Type__c;
            this.pageTheme = data.NKS_Inbox_Theme__c;
            this.pageType = data.NKS_Inbox_Type__c;
            if (!allowedThreadTypes[this.threadType].includes(actualThreadType)) this.redirect(actualThreadType);

            if (this.pageType && this.pageTheme) {
                setDecoratorParams(this.pageType, this.pageTheme);
                this.pageTitle = this.pageType + ' - ' + this.pageTheme;
            }
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
            getComponentName(this.template),
            this.pageTitle,
            'ny melding'
        );
    }
}

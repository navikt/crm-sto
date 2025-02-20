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
            let pageTheme = data.NKS_Inbox_Theme__c;
            this.pageType = data.NKS_Inbox_Type__c;

            if (!allowedThreadTypes[this.threadType].includes(actualThreadType)) {
                this.redirect(actualThreadType);
            }

            // Remove "Helse-" or "Familie-" from the beginning of pageTheme for Pleiepenger case
            if (pageTheme?.startsWith('Helse-')) {
                pageTheme = pageTheme.substring(6);
            } else if (pageTheme?.startsWith('Familie-')) {
                pageTheme = pageTheme.substring(8);
            }
            this.pageTheme = pageTheme;

            if (this.pageType && this.pageTheme) {
                setTimeout(() => {
                    setDecoratorParams(this.pageType, this.pageTheme);
                    document.title = this.tabName;
                }, '500');
            }
        }
    }

    get tabName() {
        return `${this.pageType}${this.pageTheme ? ' - ' + this.pageTheme : ''}`;
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
            `${this.pageType} - ${this.pageTheme}`,
            'ny melding'
        );
    }
}

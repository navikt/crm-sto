import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import basepath from '@salesforce/community/basePath';
import getThread from '@salesforce/apex/stoHelperClass.getThread';
import { AnalyticsEvents, logButtonEvent, setDecoratorParams, getComponentName } from 'c/inboxAmplitude';

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
    pageTitle;
    actualThreadType;
    category;

    stoCategoryMap = {
        Familie: 'Familie og barn',
        Helse: 'Helse og sykdom',
        Hjelpemidler: 'Hjelpemidler og tilrettelegging',
        Internasjonal: 'Bor eller jobber i utlandet',
        Pleiepenger: 'Pleiepenger for sykt barn'
    };

    renderedCallback() {
        // Set decorator params first when rendered
        setDecoratorParams(this.threadType, this.threadType === 'STO' ? 'Skriv til oss' : '', '');
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
            this.processThreadData(data);
        } catch (error) {
            console.error('Problem getting thread:', error);
        }
    }

    processThreadData(data) {
        this.actualThreadType = data.CRM_Thread_Type__c;
        let pageTheme = data.NKS_Inbox_Theme__c;
        this.pageTitle = data.NKS_Inbox_Title__c;
        this.category = this.stoCategoryMap[data.STO_Category__c] || data.STO_Category__c;

        if (!allowedThreadTypes[this.threadType]?.includes(this.actualThreadType)) {
            this.redirect(this.actualThreadType);
        }

        // Remove "Helse-" or "Familie-" from the beginning of pageTheme for Pleiepenger case
        if (pageTheme?.startsWith('Helse-')) {
            pageTheme = pageTheme.substring(6);
        } else if (pageTheme?.startsWith('Familie-')) {
            pageTheme = pageTheme.substring(8);
        }
        this.pageTheme = pageTheme;

        if (this.pageTitle && this.pageTheme) {
            setDecoratorParams(this.actualThreadType, this.pageTitle, this.pageTheme);
            // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
            setTimeout(() => {
                // Extra SetTimeout needed for STO to work
                document.title = this.documentTitle;
            }, '500');
        }
    }

    // Redirect for static user notifications links
    redirect(actualThreadType) {
        const link = urlMap[actualThreadType]?.(this._recordId);
        if (link) {
            // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
            window.open(link, '_self');
        } else {
            console.warn('Invalid redirect link for threadType:', actualThreadType);
        }
    }

    logAmplitudeEvent() {
        logButtonEvent(
            AnalyticsEvents.FORM_COMPLETED,
            'Send',
            getComponentName(this.template),
            `${this.pageTitle} - ${this.pageTheme}`,
            'ny melding'
        );
    }

    get documentTitle() {
        return this.threadType === 'STO' ? `Skriv til oss - ${this.category}` : `${this.pageTitle} - ${this.pageTheme}`;
    }
}

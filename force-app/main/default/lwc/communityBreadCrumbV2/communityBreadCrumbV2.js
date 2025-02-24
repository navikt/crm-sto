import { LightningElement, wire } from 'lwc';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/index';
import { loadStyle } from 'lightning/platformResourceLoader';
import { CurrentPageReference } from 'lightning/navigation';
import { updateBreadcrumbs } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

export default class CommunityBreadCrumbV2 extends LightningElement {
    recordId;
    leafnode;
    breadcrumbs = [];

    objectMap = {
        Conversation_Note__c: 'Samtalereferat',
        LiveChatTranscript: 'Chat',
        Thread__c: 'Skriv til oss'
    };

    renderedCallback() {
        loadStyle(this, index);
        loadStyle(this, navStyling);
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (!currentPageReference) return;
        const state = currentPageReference?.state;
        const name = currentPageReference?.attributes?.name;
        const objectApiName = currentPageReference?.attributes?.objectApiName;
        const samtale = state?.samtale;

        if (name === 'Visning__c' && samtale) {
            this.fetchThread(samtale);
        } else if (name === 'Home') {
            this.setHomeBreadcrumbs();
        } else if (name === 'Fedrekvotesaken') {
            this.setFedrekvoteBreadcrumbs();
        } else {
            this.setObjectBreadcrumbs(objectApiName);
        }
    }

    async fetchThread(recordId) {
        this.recordId = recordId;
        try {
            const data = await getThread({ recordId });
            this.leafnode = data?.NKS_Inbox_Title__c ?? 'Beskjed til oss';
        } catch (error) {
            console.error('Problem getting thread:', error);
            this.leafnode = 'Beskjed til oss';
        }
        this._updateBreadcrumbs();
    }

    setHomeBreadcrumbs() {
        this.breadcrumbs = [
            { url: 'https://nav.no', title: 'Privatperson' },
            { url: 'https://www.nav.no/minside/', title: 'Min side' },
            { url: '', title: 'Innboks' }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }

    setObjectBreadcrumbs(objectApiName) {
        this.leafnode = Object.keys(this.objectMap).find((key) => objectApiName?.includes(key))
            ? this.objectMap[objectApiName]
            : '';
        this._updateBreadcrumbs();
    }

    setFedrekvoteBreadcrumbs() {
        this.breadcrumbs = [{ url: '', title: 'Fedrekvotesaken' }];
        updateBreadcrumbs(this.breadcrumbs);
    }

    _updateBreadcrumbs() {
        this.breadcrumbs = [
            { url: 'https://nav.no', title: 'Privatperson' },
            { url: 'https://www.nav.no/minside/', title: 'Min side' },
            { url: 'https://innboks.nav.no', title: 'Innboks' },
            { url: '', title: this.leafnode }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }
}

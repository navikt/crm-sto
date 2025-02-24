import { LightningElement, wire } from 'lwc';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/index';
import { loadStyle } from 'lightning/platformResourceLoader';
import { CurrentPageReference } from 'lightning/navigation';
import { updateBreadcrumbs } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

const NAV_URLS = {
    home: 'https://nav.no',
    minSide: 'https://www.nav.no/minside/',
    inbox: 'https://innboks.nav.no'
};

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

        const { attributes, state } = currentPageReference;
        const { name, objectApiName } = attributes || {};
        const { samtale } = state || {};

        switch (name) {
            case 'Visning__c':
                if (samtale) this.fetchThread(samtale);
                break;
            case 'Home':
                this.setHomeBreadcrumbs();
                break;
            case 'Fedrekvotesaken':
                this.setFedrekvoteBreadcrumbs();
                break;
            default:
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
        this.updateBreadcrumbs();
    }

    setHomeBreadcrumbs() {
        this.updateBreadcrumbs([
            { url: NAV_URLS.home, title: 'Privatperson' },
            { url: NAV_URLS.minSide, title: 'Min side' },
            { url: '', title: 'Innboks' }
        ]);
    }

    setObjectBreadcrumbs(objectApiName) {
        this.leafnode = this.objectMap[objectApiName] || '';
        this.updateBreadcrumbs();
    }

    setFedrekvoteBreadcrumbs() {
        this.updateBreadcrumbs([{ url: '', title: 'Fedrekvotesaken' }]);
    }

    updateBreadcrumbs(customBreadcrumbs = null) {
        this.breadcrumbs = customBreadcrumbs || [
            { url: NAV_URLS.home, title: 'Privatperson' },
            { url: NAV_URLS.minSide, title: 'Min side' },
            { url: NAV_URLS.inbox, title: 'Innboks' },
            { url: '', title: this.leafnode }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }
}

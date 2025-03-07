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

const OBJECT_MAP = {
    Conversation_Note__c: 'Samtalereferat',
    LiveChatTranscript: 'Chat',
    Thread__c: 'Skriv til oss'
};

const TYPE_MAP = {
    Endring: 'Meld fra om endring',
    'Trekke-soknad': 'Trekke en søknad',
    Beskjed: 'Gi beskjed'
};

export default class CommunityBreadCrumbV2 extends LightningElement {
    recordId;
    leafnode;
    breadcrumbs = [];
    name;

    renderedCallback() {
        Promise.all([loadStyle(this, index), loadStyle(this, navStyling)]).catch((error) =>
            console.error('Styles failed to load:', error)
        );
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (!currentPageReference) return;

        const { attributes, state } = currentPageReference;
        this.name = attributes?.name || '';

        const { samtale, category } = state || {};

        if (this.name === 'Visning__c' && samtale) {
            this.fetchThread(samtale);
        } else if (this.name === 'Home') {
            this.leafnode = 'Innboks';
            this.breadcrumbs = [
                { url: NAV_URLS.home, title: 'Privatperson' },
                { url: NAV_URLS.minSide, title: 'Min side' },
                { url: '/', title: this.leafnode }
            ];
            this.retryBreadcrumbUpdate();
        } else if (this.name === 'Fedrekvotesaken__c') {
            this.leafnode = 'Fedrekvotesaken';
            this.breadcrumbs = [{ url: '/', title: this.leafnode }];
            this.retryBreadcrumbUpdate();
        } else {
            this.leafnode = category ? this.getCategoryTitle(category) : OBJECT_MAP[attributes?.objectApiName] || '';
            this.setBreadcrumbs();
        }
    }

    getCategoryTitle(category) {
        if (!category) return this.leafnodeName;
        const matchedKey = Object.keys(TYPE_MAP).find((key) => category.includes(key));
        return matchedKey ? TYPE_MAP[matchedKey] : this.leafnodeName;
    }

    get leafnodeName() {
        return (
            {
                Beskjed_til_oss__c: 'Beskjed til oss',
                Skriv_til_oss__c: 'Skriv til oss'
            }[this.name] || ''
        );
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
        this.setBreadcrumbs();
    }

    setBreadcrumbs() {
        this.breadcrumbs = [
            { url: NAV_URLS.home, title: 'Privatperson' },
            { url: NAV_URLS.minSide, title: 'Min side' },
            { url: NAV_URLS.inbox, title: 'Innboks' },
            { url: '/', title: this.leafnode }
        ];
        this.retryBreadcrumbUpdate();
    }

    // Retry logic for updating breadcrumbs in case of failure
    async retryWithDelay(fn, condition, attempt = 1, maxAttempts = 5, delay = 500) {
        const result = await fn();
        if (condition(result)) {
            return result;
        }

        if (attempt >= maxAttempts) {
            console.error('Max retry attempts reached.');
            return null;
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
        await new Promise((resolve) => setTimeout(resolve, delay));

        return this.retryWithDelay(fn, condition, attempt + 1, maxAttempts, delay);
    }

    async validateDecoratorReady() {
        return this.retryWithDelay(
            () => Promise.resolve(typeof window.dekoratorenIsReady === 'function'),
            (ready) => ready
        );
    }

    async retryBreadcrumbUpdate() {
        this.validateDecoratorReady().then((isReady) => {
            if (!isReady) {
                console.error('Decorator is not ready after max retries.');
                return;
            }

            this.retryWithDelay(
                () => {
                    updateBreadcrumbs(this.breadcrumbs);
                    return window.__DECORATOR_DATA__?.params?.breadcrumbs ?? false;
                },
                (breadcrumbsSet) => breadcrumbsSet
            );
        });
    }
}

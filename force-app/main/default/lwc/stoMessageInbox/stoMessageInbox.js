import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getThreads from '@salesforce/apex/stoInboxHelper.getThreads';
import getRecentThreads from '@salesforce/apex/stoInboxHelper.getRecentThreads';
import { logNavigationEvent, getComponentName, setDecoratorParams } from 'c/inboxAmplitude';

export default class StoMessageInbox extends LightningElement {
    @api title;

    threads;
    recentthreads;
    wthreads;
    wrthreads;
    showthreads = false;
    showrecentthreads = false;

    renderedCallback() {
        setDecoratorParams('Innboks', 'Innboks', '');
    }

    @wire(getThreads, {})
    wirethreads(result) {
        this.wthreads = result;
        if (result.error) {
            console.error(result.error);
        } else if (result.data) {
            this.setThreads();
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {
        this.wrthreads = result;
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.setRecentThreads();
        }
    }

    connectedCallback() {
        refreshApex(this.wthreads);
        refreshApex(this.wrthreads);
    }

    setThreads() {
        if (this.wthreads.data) {
            this.threads = [...this.wthreads.data].sort(this.sortByDate);
            this.showthreads = this.wthreads.data.length > 0;
        }
    }

    setRecentThreads() {
        if (this.wrthreads.data) {
            this.recentthreads = [...this.wrthreads.data].sort(this.sortByDate);
            this.showrecentthreads = this.wrthreads.data.length > 0;
        }
    }

    sortByDate(t1, t2) {
        let d1 = new Date(t1.latestMessageDate);
        let d2 = new Date(t2.latestMessageDate);
        if (d1 > d2) return -1;
        if (d1 < d2) return 1;
        return 0;
    }

    handleDocumentArchiveClick() {
        logNavigationEvent(
            getComponentName(this.template),
            'brev og vedtak',
            'https://www.nav.no/dokumentarkiv',
            'brev og vedtak'
        );
    }

    handleContactUsClick() {
        logNavigationEvent(
            getComponentName(this.template),
            'kontakt oss',
            'https://www.nav.no/kontaktoss',
            'Kontakt oss'
        );
    }

    get noItems() {
        return this.wthreads && this.wrthreads && !this.showrecentthreads && !this.showthreads;
    }
}

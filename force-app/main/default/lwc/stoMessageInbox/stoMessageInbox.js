import { LightningElement, wire, api } from 'lwc';
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
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.wthreads = result.data;
            this.setThreads();
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.wrthreads = result.data;
            this.setRecentThreads();
        }
    }

    get noItems() {
        return this.wthreads && this.wrthreads && !this.showrecentthreads && !this.showthreads;
    }

    setThreads() {
        if (this.wthreads) {
            this.threads = [...this.wthreads].sort(this.sortByDate);
            this.showthreads = this.wthreads.length > 0;
        }
    }

    setRecentThreads() {
        if (this.wrthreads) {
            this.recentthreads = [...this.wrthreads].sort(this.sortByDate);
            this.showrecentthreads = this.wrthreads.length > 0;
        }
    }

    sortByDate(t1, t2) {
        let d1 = new Date(t1.latestMessageDate);
        let d2 = new Date(t2.latestMessageDate);
        if (d1 > d2) {
            return -1;
        }
        if (d1 < d2) {
            return 1;
        }
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
}

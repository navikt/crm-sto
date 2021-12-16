import { LightningElement, wire, api, track } from 'lwc';

import getThreads from '@salesforce/apex/stoInboxHelper.getThreads';
import getRecentThreads from '@salesforce/apex/stoInboxHelper.getRecentThreads';

export default class StoMessageInbox extends LightningElement {
    @api title;
    @track threads;
    @track recentthreads;
    showthreads = false;
    showrecentthreads = false;

    @wire(getThreads, {})
    wirethreads(result) {
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.threads = result.data;
            if (this.threads != '') {
                this.threads.sort(this.sortByDate);
                this.showthreads = true;
            }
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.recentthreads = result.data;
            if (this.recentthreads != '') {
                this.showrecentthreads = true;
                this.recentthreads.sort(this.sortByDate);
            }
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
}

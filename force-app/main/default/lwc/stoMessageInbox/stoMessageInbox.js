import { LightningElement, wire, api } from 'lwc';

import getThreads from '@salesforce/apex/stoInboxHelper.getThreads';
import getRecentThreads from '@salesforce/apex/stoInboxHelper.getRecentThreads'; 

export default class StoMessageInbox extends LightningElement {
    @api title; 
    threads;
    recentthreads; 

    @wire(getThreads, {})
    wirethreads(result) {
        if (result.error) {
            console.log(result.error);
        }
        else if (result.data) {
            console.log(result.data);
            this.threads = result.data;
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {

        if (result.error) {
            console.log(result.error);
        }
        else if (result.data) {
            console.log(result.data);
            this.recentthreads = result.data;
        }
    }
}
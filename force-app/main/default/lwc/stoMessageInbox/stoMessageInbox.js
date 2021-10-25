import { LightningElement, wire, api } from 'lwc';

import getThreads from '@salesforce/apex/stoInboxHelper.getThreads';
import getRecentThreads from '@salesforce/apex/stoInboxHelper.getRecentThreads'; 

export default class StoMessageInbox extends LightningElement {
    @api title; 
    threads;
    recentthreads; 
    showthreads = false; 
    showrecentthreads = false; 

    @wire(getThreads, {})
    wirethreads(result) {
        if (result.error) {
            console.log(result.error);
        }
        else if (result.data) {
            this.threads = result.data;
            if(this.threads != '') this.showthreads = true; 
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {

        if (result.error) {
            console.log(result.error);
        }
        else if (result.data) {
            this.recentthreads = result.data;
            if(this.recentthreads != '')this.showrecentthreads = true; 
        }
    }
}
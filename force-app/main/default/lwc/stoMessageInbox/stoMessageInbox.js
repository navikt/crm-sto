import { LightningElement, wire } from 'lwc';

import getThreads from '@salesforce/apex/stoHelperClass.getThreads';

export default class StoMessageInbox extends LightningElement {
    dialog = navlogos + '/dialog.svg'
    threads;

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
}
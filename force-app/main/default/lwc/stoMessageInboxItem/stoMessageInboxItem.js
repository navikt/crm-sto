import { LightningElement, api, wire } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import getLatest from '@salesforce/apex/stoInboxHelper.getLatestMessage';
import basepath from '@salesforce/community/basePath';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    linkUrl;
    messageLogo = navlogos + '/email.svg';
    readLogo = navlogos + '/EmailOpen.svg';
    dialog = navlogos + '/dialog.svg';
    latestmessage;
    latestText;
    objectName; 
    threadId;
    hasunread = false;

    className;

    connectedCallback() {
        this.objectName = this.thread.objectName; 
        this.linkUrl = basepath + '/' + this.objectName + '/' + this.thread.recordId; //Implement onclick navigation
        console.log('NAVIGATE TO :' + this.linkUrl); 
        this.threadId = this.thread.recordId;
        if (Number(this.thread.CRM_Number_of_unread_Messages__c) > 0) {
            this.hasunread = true;
            this.className='unread';
            //console.log('jkjkj ' + this.template.querySelector('[data-id="inboxitem"]'));
            //this.template.querySelector('[data-id="inboxitem"]').className = 'lenkepanel';
        }
    }
    @wire(getLatest, { threadId: '$threadId' })
    wiremessage(result) {
        if (result.data) {
            this.latestmessage = result.data;
            this.latestText = result.data.messageText;
        }
    }
}
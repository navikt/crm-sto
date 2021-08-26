import { LightningElement, api, wire } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import getLatest from '@salesforce/apex/stoHelperClass.getLatestMessage';
import basepath from '@salesforce/community/basePath';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    linkUrl;
    messageLogo = navlogos + '/email.svg';
    readLogo = navlogos + '/EmailOpen.svg';
    dialog = navlogos + '/dialog.svg';
    latestmessage;
    latestText;
    threadId;
    hasunread = false;

    className;

    connectedCallback() {
        this.linkUrl = basepath + '/thread/' + this.thread.Id; //Implement onclick navigation
        this.threadId = this.thread.Id;
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
            this.latestText = result.data.CRM_Message_Text__c;
        }
    }
}
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

    className = 'lenkepanel dialog flere-meldinger .slds-size_1-of-1 read';

    connectedCallback() {
        this.objectName = this.thread.objectName; 
        this.linkUrl = basepath + '/' + this.objectName + '/' + this.thread.recordId; 
        this.threadId = this.thread.recordId;
        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasunread = true;
            this.className='lenkepanel dialog flere-meldinger .slds-size_1-of-1 unread';
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
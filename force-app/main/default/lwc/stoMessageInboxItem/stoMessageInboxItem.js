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
    isExternal;
    isOpen;;
    threadId;
    hasunread = false;
    unreadmessage = 'lest';

    className = 'lenkepanel dialog flere-meldinger .slds-size_1-of-1 read iconclass';
    statuscolor; 
    get itemTitle() {
        if(this.objectName ==='samtalereferat')
            return this.thread.name;
        if(this.objectName ==='skriv-til-oss'){
            if(this.isOpen){
                if(this.isExternal === true){
                    return this.thread.name + ': Du sendte en melding'
                }else{
                    return this.thread.name + ': NAV sendte en melding'
                }
            }
            return this.thread.name + ': Henvendelsen er avsluttet';
        }
        return this.thread.name;
    }
    connectedCallback() {
        this.objectName = this.thread.objectName; 
        this.linkUrl = basepath + '/' + this.objectName + '/' + this.thread.recordId; 
        this.threadId = this.thread.recordId;
        if(this.thread.status == 'Åpen') {
            this.statuscolor = 'greenfont';
            this.isOpen = true;
        }
        if(this.objectName == 'samtalereferat') this.dialog = navlogos + '/Notes.svg';
        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasunread = true;
            this.unreadmessage = 'ulest'; 
            this.className='lenkepanel dialog flere-meldinger .slds-size_1-of-1 unread iconclass';
        }
    }
    @wire(getLatest, { threadId: '$threadId' })
    wiremessage(result) {
        if (result.data) {
            this.latestmessage = result.data;
            this.latestText = result.data.messageText;
            this.isExternal = result.date.isExternal;
        }
    }
}
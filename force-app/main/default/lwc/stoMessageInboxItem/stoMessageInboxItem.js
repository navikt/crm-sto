import { LightningElement, api } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent } from 'c/amplitude';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;

    dialog = navlogos + '/send.svg';
    latestmessage;
    latestText;
    objectName;
    isExternal;
    isOpen;
    threadId;
    hasunread = false;
    unreadmessage = 'lest';
    className = 'lenkepanel dialog read iconclass overrides';
    statuscolor;

    connectedCallback() {
        this.objectName = this.thread.objectName;
        if (this.thread.status === 'Åpen') {
            this.statuscolor = 'greenfont';
            this.isOpen = true;
        }
        if (this.objectName === 'samtalereferat') this.dialog = navlogos + '/FileContent.svg';
        if (this.objectName === 'chat') this.dialog = navlogos + '/dialog.svg';
        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasunread = true;
            this.unreadmessage = 'ulest';
            this.className = 'lenkepanel dialog unread iconclass';
        }
        this.latestmessage = this.thread.latestmessage;
        this.latestText = this.thread.latestmessage.messageText;
        this.isExternal = this.thread.latestmessage.isExternal;
    }

    get itemTitle() {
        if (this.objectName === 'samtalereferat') return this.thread.name;
        if (this.objectName === 'skriv-til-oss' || this.objectName === 'beskjed-til-oss') {
            if (this.isOpen) {
                if (this.isExternal === true) {
                    return this.thread.name + ': Du sendte en melding';
                }
                return this.thread.name + ': Nav sendte en melding';
            }
            return this.thread.name;
        }
        if (this.objectName === 'chat') {
            if (this.isExternal === true) {
                return this.thread.name + ': Du sendte en melding';
            }
            return this.thread.name + ': Nav sendte en melding';
        }
        return this.thread.name;
    }

    get showStatus() {
        return this.objectName !== 'samtalereferat';
    }

    get linkUrl() {
        return this.objectName === 'beskjed-til-oss'
            ? basepath + '/' + this.objectName + '/visning?samtale=' + this.thread.recordId
            : basepath +
                  '/' +
                  this.objectName +
                  '/' +
                  this.thread.recordId +
                  '/' +
                  this.thread.recordName.replace(/[ -]+/g, '-');
    }

    hanldeNavigation(event) {
        logNavigationEvent(
            'innboks - henvendelser',
            'stoMessageInboxItem',
            'innboks item',
            event.target.href,
            this.itemTitle
        );
    }
}

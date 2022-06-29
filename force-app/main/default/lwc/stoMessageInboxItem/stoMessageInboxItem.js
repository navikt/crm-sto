import { LightningElement, api, wire } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import basepath from '@salesforce/community/basePath';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api contentSize = 10;
    linkUrl;
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
    get itemTitle() {
        if (this.objectName === 'samtalereferat') return this.thread.name;
        if (this.objectName === 'skriv-til-oss') {
            if (this.isOpen) {
                if (this.isExternal === true) {
                    return this.thread.name + ': Du sendte en melding';
                } else {
                    return this.thread.name + ': NAV sendte en melding';
                }
            }
            return this.thread.name;
        }
        if (this.objectName === 'chat') {
            if (this.isExternal === true) {
                return this.thread.name + ': Du sendte en melding';
            } else {
                return this.thread.name + ': NAV sendte en melding';
            }
        }
        return this.thread.name;
    }
    connectedCallback() {
        this.objectName = this.thread.objectName;
        this.linkUrl =
            basepath +
            '/' +
            this.objectName +
            '/' +
            this.thread.recordId +
            '/' +
            this.thread.recordName.replace(/[ -]+/g, '-');
        this.threadId = this.thread.recordId;
        if (this.thread.status == 'Åpen') {
            this.statuscolor = 'greenfont';
            this.isOpen = true;
        }
        if (this.objectName == 'samtalereferat') this.dialog = navlogos + '/FileContent.svg';
        if (this.objectName == 'chat') this.dialog = navlogos + '/dialog.svg';
        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasunread = true;
            this.unreadmessage = 'ulest';
            this.className = 'lenkepanel dialog unread iconclass';
        }
        this.latestmessage = this.thread.latestmessage;
        this.latestText = this.thread.latestmessage.messageText;
        this.isExternal = this.thread.latestmessage.isExternal;
    }

    get showStatus() {
        return this.objectName != 'samtalereferat';
    }

    get contentClasses() {
        return (
            'slds-size_' +
            (this.contentSize - 1) +
            '-of-12 slds-small-size_' +
            (this.contentSize - 1) +
            '-of-12 slds-medium-size_' +
            (this.contentSize - 1) +
            '-of-12 slds-large-size_' +
            this.contentSize +
            '-of-12'
        );
    }
}

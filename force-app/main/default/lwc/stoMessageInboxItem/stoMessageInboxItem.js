import { LightningElement, api } from 'lwc';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api isCloseItem = false;

    latestmessage;
    latestText;
    objectName;
    isExternal;
    isOpen;
    threadId;
    hasunread = true;
    unreadmessage = 'lest';
    statuscolor;

    connectedCallback() {
        this.objectName = this.thread.objectName;

        if (this.thread.status === 'Åpen') {
            this.statuscolor = 'greenfont';
            this.isOpen = true;
        }

        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasunread = true;
            this.unreadmessage = 'Ulest';
        }

        this.latestmessage = this.thread.latestmessage;
        this.latestText = this.thread.latestmessage.messageText;
        this.isExternal = this.thread.latestmessage.isExternal;
    }

    handleNavigation(event) {
        logNavigationEvent(getComponentName(this.template), 'valgt henvendelse', event.target.href, this.itemTitle);
    }

    get itemTitle() {
        if (this.objectName === 'samtalereferat') return this.thread.name;

        if (this.objectName === 'skriv-til-oss' || this.objectName === 'beskjed-til-oss') {
            if (this.isOpen) {
                return this.thread.name + (this.isExternal ? ': Du sendte en melding' : ': Nav sendte en melding');
            }
            return this.thread.name;
        }

        if (this.objectName === 'chat') {
            return this.thread.name + (this.isExternal ? ': Du sendte en melding' : ': Nav sendte en melding');
        }

        return this.thread.name;
    }

    get showStatus() {
        return this.objectName !== 'samtalereferat';
    }

    get showReadStatus() {
        return this.unreadmessage === 'Ulest';
    }

    get statusText() {
        return this.thread.status === 'Åpen' ? 'Aktiv' : this.thread.status;
    }

    get statusClass() {
        return (
            'navds-tag navds-tag--success navds-tag--small navds-body-short navds-body-short--small ' +
            (this.thread.status === 'Åpen' ? 'navds-tag--success' : 'navds-tag--neutral-moderate')
        );
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

    get panelClass() {
        return `panel ${this.isCloseItem ? 'no-bottom-radius' : 'border-radius'}`;
    }
}

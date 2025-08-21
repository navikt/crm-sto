import { LightningElement, api } from 'lwc';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api closeIntent = false;

    latestText;
    objectName;
    isExternal;
    isOpen;
    hasUnread = true;
    unreadMessage = 'lest';

    connectedCallback() {
        this.objectName = this.thread.objectName;

        if (this.thread.status === 'Åpen') {
            this.isOpen = true;
        }

        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasUnread = true;
            this.unreadMessage = 'Ulest';
        }

        this.latestText = this.thread.latestmessage.messageText;
        this.isExternal = this.thread.latestmessage.isExternal;
    }

    handleNavigation(event) {
        logNavigationEvent(getComponentName(this.template), 'valgt henvendelse', event.target.href, this.itemTitle);
    }

    get itemTitle() {
        if (this.objectName === 'samtalereferat') return this.thread.name;

        if (['skriv-til-oss', 'beskjed-til-oss', 'chat'].includes(this.objectName)) {
            const sender = this.isExternal ? 'Du sendte en melding' : 'Nav sendte en melding';
            return this.isOpen ? `${this.thread.name}: ${sender}` : this.thread.name;
        }

        return this.thread.name;
    }

    get showStatus() {
        return this.objectName !== 'samtalereferat';
    }

    get showReadStatus() {
        return this.unreadMessage === 'Ulest';
    }

    get statusText() {
        return this.thread.status;
    }

    get statusClass() {
        return (
            'navds-tag navds-tag--success navds-tag--small navds-body-short navds-body-short--small ' +
            (this.thread.status === 'Åpen' ? 'navds-tag--success' : 'navds-tag--alt1')
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
        return `panel ${this.closeIntent ? 'no-bottom-radius' : 'border-radius'}`;
    }
}

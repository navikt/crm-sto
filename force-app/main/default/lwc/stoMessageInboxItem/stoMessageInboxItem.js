import { LightningElement, api } from 'lwc';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api closeIntent = false;

    latestmessage;
    latestText;
    objectName;
    isExternal;
    isOpen;
    threadId;
    hasUnread = true;
    unreadmessage = 'lest';
    statuscolor;

    connectedCallback() {
        this.objectName = this.thread.objectName;

        if (this.thread.status === 'Åpen') {
            this.statuscolor = 'greenfont';
            this.isOpen = true;
        }

        if (Number(this.thread.numberOfUnreadMessages) > 0) {
            this.hasUnread = true;
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
        const isBeskjed = this.objectName === 'beskjed-til-oss';
        const base = `${basepath}/${this.objectName}`;

        if (isBeskjed) {
            return `${base}/visning?samtale=${this.thread.recordId}`;
        }

        const recordNameSlug = this.thread.recordName.replace(/[ -]+/g, '-');
        return `${base}/${this.thread.recordId}/${recordNameSlug}?closeIntent=${this.closeIntent}`;
    }

    get panelClass() {
        return `panel ${this.closeIntent ? 'no-bottom-radius' : 'border-radius'}`;
    }
}

import { LightningElement, api } from 'lwc';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api closeIntent = false;
    @api inboxPersonValue = 'self';

    get inboxSenderLabel() {
        return this.thread?.inboxSenderLabel;
    }

    handleNavigation(event) {
        logNavigationEvent(getComponentName(this.template), 'valgt henvendelse', event.target.href, this.itemTitle);
    }

    get itemTitle() {
        if (this.objectName === 'samtalereferat') return this.thread.name;

        if (['skriv-til-oss', 'beskjed-til-oss', 'chat'].includes(this.objectName)) {
            //const sender = this.isExternal ? 'Du sendte en melding' : 'Nav sendte en melding';
            // return this.isOpen ? `${this.thread.name}` : this.thread.name;
            return this.thread.name;
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

    get statusDataColor() {
        return this.thread.status === 'Åpen' ? 'success' : 'meta-purple';
    }

    get linkUrl() {
        let url = basepath;
        if (this.objectName === 'beskjed-til-oss') {
            url += '/' + this.objectName + '/visning?samtale=' + this.thread.recordId;
        } else if (this.objectName === 'skriv-til-oss' || this.objectName === 'samtalereferat') {
            url +=
                '/' +
                this.objectName +
                '/' +
                this.thread.recordId +
                '/' +
                this.thread.recordName.replace(/[ -]+/g, '-');
        } else {
            url += '/chat?id=' + this.thread.recordId;
        }
        if (this.inboxPersonValue && this.inboxPersonValue !== 'self') {
            url += `${url.includes('?') ? '&' : '?'}c__inboxPerson=${encodeURIComponent(this.inboxPersonValue)}`;
        }
        return url;
    }

    get panelClass() {
        return `panel ${this.closeIntent ? 'no-bottom-radius' : 'border-radius'}`;
    }

    get formattedLatestMessageDate() {
        if (!this.thread?.latestMessageDate) return '';
        const options = {
            year: 'numeric',
            month: 'long',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        };
        return new Intl.DateTimeFormat('nb-NO', options).format(new Date(this.thread.latestMessageDate));
    }

    get linkSummary() {
        return `${this.formattedLatestMessageDate}. ${this.showReadStatus ? this.unreadMessage : ''} . ${this.showStatus ? this.statusText : ''} . ${this.inboxSenderLabel ? this.inboxSenderLabel + '. ' : ''}${this.itemTitle} . ${this.latestText}`;
    }

    get latestText() {
        return this.thread?.latestmessage?.messageText || '';
    }

    get objectName() {
        return this.thread?.objectName;
    }

    get isExternal() {
        return this.thread?.latestmessage?.isExternal === true;
    }

    get isOpen() {
        return this.thread?.status === 'Åpen';
    }

    get unreadMessage() {
        return Number(this.thread?.numberOfUnreadMessages) > 0 ? 'Ulest' : 'lest';
    }
}

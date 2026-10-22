import { LightningElement, api, wire } from 'lwc';
import basepath from '@salesforce/community/basePath';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';
import getGroupedMessagesFromThread from '@salesforce/apex/CRM_MessageHelperExperience.getGroupedMessagesFromThread';
import getReplyContext from '@salesforce/apex/stoHelperClass.getReplyContext';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_CONTACT_FIELD from '@salesforce/schema/User.ContactId';
import THREAD_CONTACT_FIELD from '@salesforce/schema/Thread__c.CRM_Contact__c';
import { getReadMessageIds, isMessageRead, READ_STATE_EVENT } from 'c/stoReadState';

export default class StoMessageInboxItem extends LightningElement {
    @api thread;
    @api closeIntent = false;
    @api inboxPersonValue = 'self';

    currentUserContactId;
    ownerContactId;
    messageGroups;
    readMessageIds = [];
    readStateLoadFailed = false;
    identityLoadFailed = false;
    ownerLoadFailed = false;
    inboxSenderLabel;
    senderContextLoadFailed = false;

    @wire(getReplyContext, { threadId: '$readStateThreadId' })
    wiredReplyContext({ data, error }) {
        this.inboxSenderLabel = data?.inboxSenderLabel;
        this.senderContextLoadFailed = Boolean(error);
        if (error) console.error('Could not load inbox original sender:', error);
    }

    refreshLocalReadState = () => {
        this.readMessageIds = getReadMessageIds(USER_ID, this.thread?.recordId);
    };

    connectedCallback() {
        this.refreshLocalReadState();
        window.addEventListener(READ_STATE_EVENT, this.refreshLocalReadState);
        window.addEventListener('storage', this.refreshLocalReadState);
    }

    disconnectedCallback() {
        window.removeEventListener(READ_STATE_EVENT, this.refreshLocalReadState);
        window.removeEventListener('storage', this.refreshLocalReadState);
    }

    get readStateThreadId() {
        return this.objectName === 'skriv-til-oss' || this.objectName === 'beskjed-til-oss'
            ? this.thread?.recordId
            : undefined;
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_CONTACT_FIELD] })
    wiredCurrentUser({ data, error }) {
        this.identityLoadFailed = Boolean(error);
        if (data) {
            this.currentUserContactId = getFieldValue(data, USER_CONTACT_FIELD);
        } else if (error) {
            this.currentUserContactId = undefined;
            console.error('Could not load inbox viewer identity:', error);
        }
    }

    @wire(getRecord, { recordId: '$readStateThreadId', fields: [THREAD_CONTACT_FIELD] })
    wiredOwner({ data, error }) {
        this.ownerLoadFailed = Boolean(error);
        if (data) {
            this.ownerContactId = getFieldValue(data, THREAD_CONTACT_FIELD);
        } else if (error) {
            this.ownerContactId = undefined;
            console.error('Could not load inbox thread owner:', error);
        }
    }

    @wire(getGroupedMessagesFromThread, { threadId: '$readStateThreadId' })
    wiredMessageGroups({ data, error }) {
        this.messageGroups = data;
        this.readStateLoadFailed = Boolean(error);
        if (error) {
            console.error('Could not load inbox message read context:', error);
        }
        this.refreshLocalReadState();
    }

    get messages() {
        return (this.messageGroups || []).flatMap((group) => (group.groupMessages || []).map((entry) => entry.message));
    }

    get hasReadContext() {
        return Boolean(this.ownerContactId && this.currentUserContactId && this.messageGroups);
    }

    get latestMessage() {
        return this.messages.find((message) => message.Id === this.thread?.latestmessage?.recordId);
    }

    get isSharedConversation() {
        const firstExternalMessage = this.messages.find((message) => message.CRM_External_Message__c);
        return (
            this.hasReadContext &&
            (this.ownerContactId !== this.currentUserContactId ||
                (firstExternalMessage?.CRM_From_Contact__c &&
                    firstExternalMessage.CRM_From_Contact__c !== this.ownerContactId))
        );
    }

    get readStateUnavailable() {
        return Boolean(
            this.readStateThreadId && (!this.hasReadContext || this.readStateLoadFailed || !this.latestMessage)
        );
    }

    get showReadStateError() {
        return Boolean(
            this.readStateThreadId &&
                (this.readStateLoadFailed ||
                    this.identityLoadFailed ||
                    this.ownerLoadFailed ||
                    (this.hasReadContext && !this.latestMessage))
        );
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
        if (this.readStateThreadId) {
            // Do not mistake a global "read" flag for this viewer's receipt while metadata is unavailable.
            if (this.readStateUnavailable) return '';
            if (this.isSharedConversation) {
                const latestId = this.thread?.latestmessage?.recordId;
                return isMessageRead(
                    this.readMessageIds,
                    latestId,
                    this.latestMessage.CRM_From_Contact__c,
                    this.currentUserContactId
                )
                    ? 'lest'
                    : 'Ulest';
            }
        }
        return Number(this.thread?.numberOfUnreadMessages) > 0 ? 'Ulest' : 'lest';
    }
}

import { LightningElement, wire, api } from 'lwc';
import getGroupedMessagesFromThread from '@salesforce/apex/CRM_MessageHelperExperience.getGroupedMessagesFromThread';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import createThreadMessage from '@salesforce/apex/CRM_MessageHelperExperience.createThreadMessage';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import getCloseIntent from '@salesforce/apex/stoHelperClass.getCloseIntent';
import getReplyContext from '@salesforce/apex/stoHelperClass.getReplyContext';

import THREAD_NAME_FIELD from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import THREAD_CLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';
import CATEGORY_FIELD from '@salesforce/schema/Thread__c.STO_Category__c';
import { latestDisplayedMessage, markMessagesRead } from 'c/stoReadState';

const fields = [THREAD_NAME_FIELD, THREAD_CLOSED_FIELD, THREAD_TYPE_FIELD, CATEGORY_FIELD];

export default class CommunityThreadViewer extends LightningElement {
    @api recordId;
    @api openAlertText;
    @api maxLength;
    @api overrideValidation = false;
    @api errorList = { title: '', errors: [] };
    @api logAmplitudeEvent = false;

    wiredMessages;
    buttonDisabled = false;
    isSending = false;
    messageValue;
    thread;
    wiredThread;
    messageGroups;
    showSpinner = false;
    showCloseButton = false;
    referrer;
    replyContext;
    replyContextError;
    readStateError;
    readPositionPending;
    lastReadMessageId;

    @wire(getReplyContext, { threadId: '$recordId' })
    wiredReplyContext({ data, error }) {
        this.replyContext = data;
        this.replyContextError = error
            ? 'Vi kunne ikke hente hvem som kan svare i samtalen. Oppdater siden og prøv på nytt.'
            : undefined;
        if (error) console.error('Problem getting reply access:', error);
    }

    connectedCallback() {
        this.referrer = document.referrer.toLowerCase();
    }

    renderedCallback() {
        if (this.showSpinner) {
            this.template.querySelector('c-ds-loader')?.focus();
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredRecord(result) {
        this.wiredThread = result;
        const { error, data } = result;
        if (data) {
            this.thread = data;
            if (this.category) {
                getCloseIntent({ category: this.category })
                    .then((closeIntent) => {
                        if (
                            this.referrer.includes(`skriv-til-oss?category=${this.category.toLowerCase()}`) &&
                            closeIntent
                        ) {
                            this.showCloseButton = true;
                        }
                    })
                    .catch((err) => {
                        console.error('Problem on getting close intent: ', JSON.stringify(err));
                    });
            }
        } else if (error) {
            console.error('Problem getting thread record: ', error);
        }
    }

    @wire(getGroupedMessagesFromThread, { threadId: '$recordId' })
    wiredGroups(result) {
        this.wiredMessages = result;
        const { error, data } = result;
        if (error) {
            console.error('Problem getting message groups: ', error);
        } else if (data) {
            this.messageGroups = result.data;
            this.saveDisplayedReadPosition();
        }
    }

    async saveDisplayedReadPosition() {
        const latest = latestDisplayedMessage(this.messageGroups || []);
        if (!latest || latest.Id === this.lastReadMessageId || this.readPositionPending) return;
        const threadId = this.recordId;
        this.readPositionPending = true;
        try {
            await markMessagesRead(threadId, latest.Id);
            this.lastReadMessageId = latest.Id;
            this.readStateError = undefined;
        } catch (error) {
            console.error('Could not save thread read position:', error);
            this.readStateError = 'Lesestatus kunne ikke lagres. Oppdater siden og prøv på nytt.';
        } finally {
            this.readPositionPending = false;
        }
        if (!this.readStateError && latestDisplayedMessage(this.messageGroups || [])?.Id !== latest.Id) {
            this.saveDisplayedReadPosition();
        }
    }

    /**
     * Blanks out all text fields and refreshes the messages.
     * @Author lars Petter Johnsen
     */
    handlesuccess() {
        const textBoks = this.template.querySelector('c-ds-textarea');
        textBoks.clearText();
        return refreshApex(this.wiredMessages);
    }

    handleMessageFailed() {
        this.buttonDisabled = true;
        refreshApex(this.wiredMessages);
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.errorList = {
            title: 'Denne samtalen har blitt avsluttet.',
            errors: [
                {
                    Id: 1,
                    EventItem: '',
                    Text: 'Vil du <a href="https://www.nav.no/skriv-til-oss" target="_self">sende en ny melding</a>, kan du gjøre det her. Husk å kopiere det du har skrevet.'
                }
            ]
        };
        let errorSummary = this.template.querySelector('.errorSummary');
        errorSummary.focusHeader();
    }

    async createMessage(validation) {
        if (!this.canReply || this.isSending) return;
        if (!validation) {
            this.buttonDisabled = false;
            return;
        }

        this.isSending = true;
        this.buttonDisabled = true;
        try {
            const result = await createThreadMessage({ threadId: this.recordId, messageText: this.messageValue });
            if (result) {
                await this.handlesuccess();
                this.buttonDisabled = false;
            } else {
                this.handleMessageFailed();
            }
        } catch (error) {
            console.error('Problem sending message: ', error);
            this.buttonDisabled = false;
            this.template.querySelector('c-alertdialog').showModal();
        } finally {
            this.isSending = false;
        }
    }

    get canReply() {
        return this.replyContext?.canReply === true;
    }

    get showReadOnlyNotice() {
        return this.closed === false && this.replyContext?.canReply === false;
    }

    get representationLabel() {
        return this.replyContext?.representedLabel || '';
    }

    handleSendButtonClick() {
        if (!this.canReply || this.buttonDisabled || this.isSending) return;
        this.buttonDisabled = true;
        // Sending out event to parent to handle any needed validation
        if (this.overrideValidation) {
            const validationEvent = new CustomEvent('validationevent', {
                message: this.messageValue,
                maxLength: this.maxLength
            });
            this.dispatchEvent(validationEvent);
        } else {
            // Using default validation
            this.createMessage(this.valid());
        }

        if (this.logAmplitudeEvent) {
            this.dispatchEvent(new CustomEvent('logevent'));
        }
    }

    valid() {
        // This function will never run of errorList is defined from parent with overrideValidation
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.errorList = { title: 'For å sende melding må du rette følgende:', errors: [] };
        if (!this.messageValue || this.messageValue.length == null) {
            this.errorList.errors.push({ Id: 1, EventItem: '.inputTextbox', Text: 'Tekstboksen kan ikke være tom.' });
        } else if (this.maxLength !== 0 && this.maxLength != null && this.messageValue.length > this.maxLength) {
            this.errorList.errors.push({
                Id: 2,
                EventItem: '.inputTextbox',
                Text: 'Det er for mange tegn i tekstboksen.'
            });
        } else {
            return true;
        }
        let errorSummary = this.template.querySelector('.errorSummary');
        errorSummary.focusHeader();
        return false;
    }

    handleTextChange(event) {
        this.messageValue = event.detail;
    }

    handleErrorClick(event) {
        let item = this.template.querySelector(event.detail);
        item.focus();
    }

    handleClick() {
        if (!this.canReply) return;
        this.refs.childRef.openModal();
    }

    handleCloseThread() {
        if (!this.canReply) return;
        this.refs.childRef.closeModal();
        this.showSpinner = true;
        closeThread({ id: this.recordId })
            .then(() => {
                return refreshApex(this.wiredThread);
            })
            .then(() => {
                this.showSpinner = false;
                this.showCloseButton = false;
                window.location.reload();
            })
            .catch((err) => {
                console.error(err);
                this.showSpinner = false;
                this.template.querySelector('c-alertdialog').showModal();
            });
    }

    get threadType() {
        return getFieldValue(this.thread, THREAD_TYPE_FIELD);
    }

    get isSTO() {
        return this.threadType === 'STO' || this.threadType === 'STB';
    }

    get showOpenWarning() {
        if (this.openAlertText) {
            return !this.isSTO;
        }
        return false;
    }

    get name() {
        return getFieldValue(this.thread, THREAD_NAME_FIELD);
    }

    get closed() {
        return getFieldValue(this.thread, THREAD_CLOSED_FIELD);
    }

    get showClosedText() {
        return this.closed && !this.isSTO;
    }

    get inboxTheme() {
        const name = this.name;
        if (!name) return '';
        const parts = name.split('-');
        return parts[0].trim();
    }

    get inboxType() {
        const name = this.name;
        if (!name) return '';
        const dashIndex = name.indexOf('-');
        const colonIndex = name.indexOf(':');

        if (dashIndex !== -1 && colonIndex !== -1 && colonIndex > dashIndex) {
            return name.substring(dashIndex + 1, colonIndex).trim();
        } else if (dashIndex !== -1 && (colonIndex === -1 || colonIndex < dashIndex)) {
            return name.substring(dashIndex + 1).trim();
        }
        return name.trim();
    }

    get category() {
        return getFieldValue(this.thread, CATEGORY_FIELD);
    }

    get isWritingForChild() {
        return this.replyContext?.isWritingForChild === true;
    }

    // TODO(backend-ready): Preserve both readability and session-loss notices with perspective-correct wording.
    get descriptionTextArea() {
        const description =
            'Teksten lagres ikke automatisk. Hvis du er på denne siden i mer enn 30 minutter, kan du bli logget ut og miste det du har skrevet.';
        if (this.isWritingForChild) {
            return `Personen du sender melding på vegne av kan lese meldingen i fremtiden. Hvis en annen person har foreldreansvar, vil den personen kunne lese meldingene også. ${description}`;
        }
        if (this.replyContext?.wasStartedOnBehalfOfOwner === true) {
            return `Denne samtalen ble startet på vegne av deg. Hvis noen har foreldreansvar for deg, kan de også lese meldingene. ${description}`;
        }
        return description;
    }
}

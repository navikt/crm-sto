import { LightningElement, wire, api } from 'lwc';
import getGroupedMessagesFromThread from '@salesforce/apex/CRM_MessageHelperExperience.getGroupedMessagesFromThread';
import markAsRead from '@salesforce/apex/CRM_MessageHelperExperience.markAsRead';
import { refreshApex } from '@salesforce/apex';
import getContactId from '@salesforce/apex/CRM_MessageHelperExperience.getUserContactId';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import createMessage from '@salesforce/apex/CRM_MessageHelperExperience.createMessage';
import { CurrentPageReference } from 'lightning/navigation';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';

import THREADNAME_FIELD from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import THREADCLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';

const fields = [THREADNAME_FIELD, THREADCLOSED_FIELD, THREAD_TYPE_FIELD];

export default class CommunityThreadViewer extends LightningElement {
    @api recordId;
    @api openAlertText;
    @api maxLength;
    @api overrideValidation = false;
    @api errorList = { title: '', errors: [] };
    @api logAmplitudeEvent = false;

    wiredMessages;
    buttonDisabled = false;
    messageValue;
    userContactId;
    thread;
    wiredThread;
    messageGroups;
    showCloseButton = false;
    showSpinner = false;
    currentPageReference;

    connectedCallback() {
        markAsRead({ threadId: this.recordId });
        getContactId({})
            .then((contactId) => {
                this.userContactId = contactId;
            })
            .catch((error) => {
                console.error('Problem on getting contact id: ', error);
            });
    }

    renderedCallback() {
        if (this.showSpinner) {
            this.template.querySelector('.spinner')?.focus();
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        this.currentPageReference = currentPageReference;
        if (currentPageReference?.state?.closeIntent === 'true') {
            this.showCloseButton = true;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredRecord(result) {
        this.wiredThread = result;
        const { error, data } = result;
        if (data) {
            this.thread = data;
            const state = this.currentPageReference?.state;
            if (state?.closeIntent === 'true') {
                this.showCloseButton = !this.closed;
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
        }
    }

    /**
     * Blanks out all text fields, and enables the submit-button again.
     * @Author lars Petter Johnsen
     */
    handlesuccess() {
        const inputFields = this.template.querySelectorAll('.messageText');
        if (inputFields) {
            inputFields.forEach((field) => {
                field.reset();
            });
        }
        const textBoks = this.template.querySelector('c-community-textarea');
        textBoks.clearText();
        this.buttonDisabled = false;
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
                    Text: 'Vil du <a href="https://www.nav.no/person/kontakt-oss/nb/skriv-til-oss">sende en ny melding</a>, kan du gjøre det her. Husk å kopiere det du har skrevet.'
                }
            ]
        };
        let errorSummary = this.template.querySelector('.errorSummary');
        errorSummary.focusHeader();
    }

    /**
     * Creates a message through apex
     */
    @api
    createMessage(validation) {
        if (validation !== true) {
            this.buttonDisabled = false;
            return;
        }
        createMessage({ threadId: this.recordId, messageText: this.messageValue, fromContactId: this.userContactId })
            .then((result) => {
                if (result === true) {
                    this.handlesuccess();
                } else {
                    this.handleMessageFailed();
                }
            })
            .catch((error) => console.log(error));
    }

    handleSendButtonClick() {
        this.buttonDisabled = true;
        // Sending out event to parent to handle any needed validation
        if (this.overrideValidation === true) {
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
        this.errorList = { title: '', errors: [] };
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
        this.refs.childRef.openModal();
    }

    handleCloseThread() {
        this.refs.childRef.closeModal();
        this.showSpinner = true;
        closeThread({ id: this.recordId })
            .then(() => {
                return refreshApex(this.wireThread);
            })
            .then(() => {
                this.showSpinner = false;
                window.location.reload();
            })
            .catch((err) => {
                console.error(err);
                this.showSpinner = false;
            });
    }

    get isSTO() {
        const value = getFieldValue(this.thread, THREAD_TYPE_FIELD);
        return value === 'STO' || value === 'STB';
    }

    get showOpenWarning() {
        if (this.openAlertText) {
            return !this.isSTO;
        }
        return false;
    }

    get name() {
        return getFieldValue(this.thread, THREADNAME_FIELD);
    }

    get closed() {
        return getFieldValue(this.thread, THREADCLOSED_FIELD);
    }

    get showClosedText() {
        return this.closed && !this.isSTO;
    }

    get inboxType() {
        const name = this.name;
        if (!name) return '';
        const parts = name.split('-');
        return parts[0].trim();
    }

    get inboxTheme() {
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
}

import { LightningElement, wire, api } from 'lwc';
import getGroupedMessagesFromThread from '@salesforce/apex/stoInboxHelper.getGroupedMessagesFromThread';
import markAsRead from '@salesforce/apex/CRM_MessageHelperExperience.markAsRead';
import { refreshApex } from '@salesforce/apex';
import getContactId from '@salesforce/apex/CRM_MessageHelperExperience.getUserContactId';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import createMessage from '@salesforce/apex/CRM_MessageHelperExperience.createMessage';
import THREADNAME_FIELD from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import THREADCLOSED_FIELD from '@salesforce/schema/Thread__c.CRM_Is_Closed__c';
import THREAD_TYPE_FIELD from '@salesforce/schema/Thread__c.CRM_Type__c';
import { loadStyle } from 'lightning/platformResourceLoader';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/newIndex';

const fields = [THREADNAME_FIELD, THREADCLOSED_FIELD, THREAD_TYPE_FIELD];

export default class CrmCommunityThreadViewer extends LightningElement {
    @api recordId;
    @api closedAlertText = 'Dialogen er lukket.';
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
    messageGroups;

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
        loadStyle(this, navStyling);
        loadStyle(this, index);
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    wirethread(result) {
        this.thread = result;
    }

    @wire(getGroupedMessagesFromThread, { threadId: '$recordId' })
    wiredGroups(result) {
        this.wiredMessages = result;
        if (result.error) {
            this.error = result.error;
        } else if (result.data) {
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

    get isSTO() {
        const value = getFieldValue(this.thread.data, THREAD_TYPE_FIELD);
        return value === 'STO' || value === 'STB';
    }

    get showOpenWarning() {
        if (this.openAlertText) {
            return !this.isSTO;
        }
        return false;
    }

    get name() {
        return getFieldValue(this.thread.data, THREADNAME_FIELD);
    }

    get isclosed() {
        return getFieldValue(this.thread.data, THREADCLOSED_FIELD);
    }

    get showClosedText() {
        return this.isclosed && !this.isSTO;
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

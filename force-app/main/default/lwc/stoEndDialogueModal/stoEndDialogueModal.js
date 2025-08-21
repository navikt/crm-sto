import { LightningElement, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';
import { AnalyticsEvents, logButtonEvent, logModalEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoEndDialogueModal extends LightningElement {
    showModal = false;

    @wire(MessageContext)
    messageContext;

    @api
    openModal() {
        this.showModal = true;
        this.modal.focusModal();

        publish(this.messageContext, globalModalOpen, { status: 'true' });
        logModalEvent(true, 'Avslutt samtale', getComponentName(this.template), 'Avslutt samtale modal');
    }

    @api
    closeModal() {
        this.showModal = false;

        publish(this.messageContext, globalModalOpen, { status: 'false' });
        logModalEvent(false, 'Avslutt samtale', getComponentName(this.template), 'Avslutt samtale modal');
    }

    closeThread() {
        logButtonEvent(
            AnalyticsEvents.FORM_COMPLETED,
            'Ja avslutt samtale',
            getComponentName(this.template),
            'Avslutt samtale modal'
        );
        window.scrollTo({ top: 0, behavior: 'smooth' });
        this.dispatchEvent(new CustomEvent('closethread'));
    }

    handleKeyboardEvent(event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            this.closeModal();
        }
    }

    handleFocusLast() {
        this.template.querySelector('.lastFocusElement').focus();
    }

    get modal() {
        return this.template.querySelector('c-community-modal');
    }
}

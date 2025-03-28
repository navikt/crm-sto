import { LightningElement, api, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';
import { AnalyticsEvents, logButtonEvent, logModalEvent, getComponentName } from 'c/inboxAmplitude';

export default class StoInboxCloseItem extends LightningElement {
    @api thread;
    @api index;

    modalOpen = false;

    @wire(MessageContext)
    messageContext;

    get backdropClass() {
        return this.modalOpen === false ? 'slds-hide' : 'backdrop';
    }

    get statusColor() {
        return this.thread.status === 'Åpen' ? 'greenfont' : '';
    }

    //##################################//
    //########    MODAL    #############//
    //##################################//

    get modal() {
        return this.template.querySelector('c-community-modal');
    }

    openModal() {
        this.modalOpen = true;
        this.modal.focusModal();
        publish(this.messageContext, globalModalOpen, { status: 'true' });
        logModalEvent(true, 'Avslutt samtale', getComponentName(this.template), 'Dine åpne samtaler');
    }

    closeModal() {
        this.modalOpen = false;
        const btn = this.template.querySelector('.endDialogBtn');
        btn.focus();
        publish(this.messageContext, globalModalOpen, { status: 'false' });
        logModalEvent(false, 'Avslutt samtale', getComponentName(this.template), 'Dine åpne samtaler');
    }

    closeThread() {
        const closeThreadEvent = new CustomEvent('closethread', {
            detail: this.index
        });
        this.dispatchEvent(closeThreadEvent);
        logButtonEvent(
            AnalyticsEvents.FORM_COMPLETED,
            'Ja avslutt samtale',
            getComponentName(this.template),
            'Dine åpne samtaler'
        );
    }

    handleKeyboardEvent(event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            this.closeModal();
        }
    }

    handleFocusLast() {
        this.template.querySelector('.lastFocusElement').focus();
    }

    get threadName() {
        return this.thread.name + (this.isExternal ? ': Du sendte en melding' : ': Nav sendte en melding');
    }
}

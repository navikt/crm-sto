import { LightningElement, api, wire } from 'lwc';

import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';

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
    }

    closeModal() {
        this.modalOpen = false;
        const btn = this.template.querySelector('.endDialogBtn');
        btn.focus();
        publish(this.messageContext, globalModalOpen, { status: 'false' });
    }

    closeThread() {
        const closeThreadEvent = new CustomEvent('closethread', {
            detail: this.index
        });
        this.dispatchEvent(closeThreadEvent);
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
        return this.thread.name + (this.isExternal === true ? ': Du sendte en melding' : ': NAV sendte en melding');
    }
}

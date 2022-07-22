import { LightningElement, api } from 'lwc';

export default class StoInboxCloseItem extends LightningElement {
    @api thread;
    @api index;
    hideModal = true;
    bufferModalFocus = false;

    renderedCallback() {
        //Fungerer ikke, må sjekke
        console.log('Heisann');
        if (this.bufferModalFocus === true) {
            const modal = this.template.querySelector('.northCopy');
            if (modal) {
                console.log('Focusing');
                modal.focus();
                this.bufferModalFocus = false;
            }
        }
    }

    get modalClass() {
        return 'slds-modal slds-show uiPanelCopy northCopy' + (this.hideModal === true ? '' : ' slds-fade-in-open');
    }

    get backdropClass() {
        return this.hideModal === true ? 'slds-hide' : 'backdrop';
    }

    //##################################//
    //########    MODAL    #############//
    //##################################//

    openModal() {
        this.hideModal = false;
        this.bufferModalFocus = true;
    }

    closeModal() {
        this.hideModal = true;
        const btn = this.template.querySelector('.endDialogBtn');
        btn.focus();
    }

    trapFocusStart() {
        const firstElement = this.template.querySelector('.closeButton');
        firstElement.focus();
    }

    trapFocusEnd() {
        const lastElement = this.template.querySelector('.cancelButton');
        lastElement.focus();
    }

    closeThread() {
        const closeThreadEvent = new CustomEvent('closethread', {
            detail: this.index
        });
        this.dispatchEvent(closeThreadEvent);
    }
}

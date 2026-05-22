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
        this.dispatchEvent(new CustomEvent('closethread'));
    }
}

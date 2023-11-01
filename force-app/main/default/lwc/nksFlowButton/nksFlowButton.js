import { LightningElement, api, wire } from 'lwc';
import { MessageContext, publish } from 'lightning/messageService';
import AMPLITUDE_CHANNEL from '@salesforce/messageChannel/amplitude__c';

export default class NksFlowButton extends LightningElement {
    @api flowName;
    @api buttonLabel;
    @api buttonColor;
    @api inputVariables;
    @api isDisabled = false;

    showFlow = false;

    @wire(MessageContext)
    messageContext;

    get ariaExpanded() {
        return this.showFlow.toString();
    }

    get buttonClassName() {
        let color = this.buttonColor?.toLowerCase();
        switch (color) {
            case 'blue':
                return 'button blue';

            case 'green':
                return 'button green';

            default:
                return 'button';
        }
    }

    toggleFlow() {
        let message = {
            eventType: 'STO',
            properties: { type: 'STO' + this.buttonLabel + 'pressed' }
        };
        publish(this.messageContext, AMPLITUDE_CHANNEL, message);
        this.showFlow = !this.showFlow;
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
        this.dispatchEvent(new CustomEvent('flowfinished'));
    }
}

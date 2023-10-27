import { LightningElement, wire } from 'lwc';
import { MessageContext, publish } from 'lightning/messageService';
import AMPLITUDE_CHANNEL from '@salesforce/messageChannel/amplitude__c';

export default class NksAmplitudeTest extends LightningElement {
    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        console.log('NksAmplitudeTest connected');
    }

    sendMessage() {
        const message = {
            recordId: 'exampleId',
            type: 'LWC Event',
            options: { data: '123', moreData: '1234' }
        };

        console.log('Message to send: ', JSON.stringify(message));
        publish(this.messageContext, AMPLITUDE_CHANNEL, message);
    }
}

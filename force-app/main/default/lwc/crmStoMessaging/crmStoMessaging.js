import { LightningElement, api } from 'lwc';

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;

    connectedCallback() {
        this.template.addEventListener('toolbaraction', (event) => {
            let flowInputs = [];
            //logic to validate and create correct flowInputs for the flow to be triggered
            switch (event.detail.flowName) {
                case 'CRM_Case_Journal_STO_Thread':
                    flowInputs = [
                        {
                            name: 'Thread_ID',
                            type: 'String',
                            value: event.detail.threadId
                        }
                    ];
                    //Adding the flowInputs parameters to the event
                    event.detail.flowInputs = flowInputs;
                    break;
                case 'CRM_STO_transfer':
                    flowInputs = [
                        {
                            name: 'recordId',
                            type: 'String',
                            value: this.recordId
                        }
                    ];
                    break;
                default:
                    break;
            }
            //Adding the flowInputs parameters to the event
            event.detail.flowInputs = flowInputs;

            this.dispatchToolbarAction(event); //Forwards the event to parent
        });
    }

    dispatchToolbarAction(event) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('toolbaraction', event);

        this.dispatchEvent(toolbarActionEvent);
    }

    get isCase() {
        return this.objectApiName === 'Case';
    }
}

import { LightningElement, api } from 'lwc';

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;
    @api cardTitle;

    connectedCallback() {
        this.template.addEventListener('toolbaraction', event => {
            let flowInputs = [];
            //logic to validate and create correct flowInputs for the flow to be triggered
            switch (event.detail.flowName) {
                case 'CRM_Case_Journal_STO_Thread':
                    flowInputs = [
                        {
                            name: 'Thread_ID',
                            type: 'String',
                            value: event.threadId
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
                        },
                        {
                            name: 'Thread_ID',
                            type: 'String',
                            value: event.threadId
                        }
                    ];
                    break;
                default:
                    break;
            }
            //Adding the flowInputs parameters to the event
            event.detail.flowInputs = flowInputs;

            this.dispatchStoToolbarAction(event); //Forwards the event to parent
        });
    }

    dispatchStoToolbarAction(event) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('sto_toolbaraction', event);

        this.dispatchEvent(toolbarActionEvent);
    }
}

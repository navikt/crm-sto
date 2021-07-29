import { LightningElement, api } from 'lwc';

export default class CrmStoMessaging extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api singleThread;

    startTransferFlow() {
        this.dispatchToolbarAction('NKS_STO_transfer');
    }

    dispatchToolbarAction(flowName) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('toolbaraction', {
            detail: { flowName }
        });

        this.dispatchEvent(toolbarActionEvent);
    }

    get isCase() {
        return this.objectApiName === 'Case';
    }
}

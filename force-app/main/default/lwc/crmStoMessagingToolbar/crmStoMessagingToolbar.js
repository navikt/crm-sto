import { LightningElement, api } from 'lwc';

export default class CrmStoMessagingToolbar extends LightningElement {
    @api objectApiName;

    // startTransferFlow() {
    //     this.dispatchToolbarAction('CRM_STO_transfer');
    // }

    startJournalFlow() {
        this.dispatchToolbarAction('CRM_Case_Journal_STO_Thread');
    }

    dispatchToolbarAction(flowName) {
        //Sending event to parent to initialize flow
        const toolbarActionEvent = new CustomEvent('toolbaraction', {
            detail: { flowName },
            bubbles: true
        });

        this.dispatchEvent(toolbarActionEvent);
    }

    get isCase() {
        return this.objectApiName === 'Case';
    }
}

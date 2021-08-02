import { LightningElement, api } from 'lwc';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';

export default class CrmRecordChangeNotifier extends LightningElement {
    @api recordId;
    @api autoFlowFinish = false;

    connectedCallback() {
        this.notifyChange();
        if (this.autoFlowFinish === true) this.fireFlowFinish();
    }

    fireFlowFinish() {
        //Fires the finish event
        const finishEvent = new FlowNavigationFinishEvent();
        this.dispatchEvent(finishEvent);
    }

    @api
    notifyChange() {
        getRecordNotifyChange([{ recordId: this.recordId }]); //Triggers refresh of standard and custom components wired to the record ID
    }
}

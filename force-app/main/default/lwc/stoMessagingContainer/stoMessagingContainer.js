import { LightningElement, api, track } from 'lwc';
import PUT_BACK_LABEL from '@salesforce/label/c.NKS_Put_Back';
import RESERVE_LABEL from '@salesforce/label/c.NKS_Reserve_For_Me';
import TRANSFER_LABEL from '@salesforce/label/c.NKS_Transfer';
import { publishToAmplitude } from 'c/amplitude';

export default class StoMessagingContainer extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api showPanel = false;
    @api cardTitle = '';
    @api showClose = false;
    @api checkMedskriv = false;

    @track singleThread = true;

    showFlow = false;
    showReserve = false;
    showPutBack = false;
    showTransfer = false;
    labels = { RESERVE_LABEL, PUT_BACK_LABEL, TRANSFER_LABEL };
    label;

    get isThread() {
        return this.objectApiName === 'Thread__c';
    }

    get reserveFlowName() {
        return this.isThread ? 'STO_Action_Reserve' : 'STO_Case_Set_Reserved';
    }

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    toggleFlow(event) {
        this.showFlow = !this.showFlow;
        this.label = event.target.label;
        this.handleShowFlows();
        publishToAmplitude('STO', { type: this.label + ' pressed' });
    }

    handleShowFlows() {
        this.showReserve = this.label === this.labels.RESERVE_LABEL;
        this.showPutBack = this.label === this.labels.PUT_BACK_LABEL;
        this.showTransfer = this.label === this.labels.TRANSFER_LABEL;
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
    }

    /** Modal */

    renderedCallback() {
        const modal = this.template.querySelector('.firstfocusable');
        if (modal) {
            modal.focus();
        }
    }

    closeModal() {
        this.showPanel = false;
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.showPanel = false;
        }
    }

    handleModalKey(event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            this.closeModal();
        } else if (event.keyCode === 9 || event.code === 'Tab') {
            const el = document.activeElement;
            if (el.classList.contains('lastfocusable') || el.classList.contains('firstfocusable')) {
                this.template.querySelector('[data-id="focusElement"]').focus();
            }
        }
    }
}

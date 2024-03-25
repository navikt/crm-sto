import { LightningElement, api, track } from 'lwc';
import PUT_BACK_LABEL from '@salesforce/label/c.NKS_Put_Back';
import RESERVE_LABEL from '@salesforce/label/c.NKS_Reserve_For_Me';
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
    labels = { RESERVE_LABEL, PUT_BACK_LABEL };
    label;

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
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
    }

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

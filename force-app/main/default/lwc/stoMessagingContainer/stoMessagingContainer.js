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

    reserve = RESERVE_LABEL;
    putBack = PUT_BACK_LABEL;
    showFlow = false;
    showReserve = false;
    showPutBack = false;
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
        if (this.label === this.reserve) {
            this.showReserve = true;
            this.showPutBack = false;
        }

        if (this.label === this.putBack) {
            this.showPutBack = true;
            this.showReserve = false;
        }
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

    handleToolbarAction(event) {
        const flowName = event.detail.flowName;
        const flowInputs = event.detail.flowInputs;
        this.showPanel = true;

        const flow = this.template.querySelector('lightning-flow');
        flow.startFlow(flowName, flowInputs);
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            // Closes the modal when the flow finishes
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

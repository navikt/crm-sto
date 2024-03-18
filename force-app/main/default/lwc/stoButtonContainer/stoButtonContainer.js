import { LightningElement, api } from 'lwc';
import COMPLETE_LABEL from '@salesforce/label/c.STO_Complete';
import CREATE_NAV_TASK_LABEL from '@salesforce/label/c.STO_Create_NAV_Task';
import JOURNAL_LABEL from '@salesforce/label/c.STO_Journal';
import END_DIALOGUE_LABEL from '@salesforce/label/c.STO_End_Dialogue';
import SEND_TO_REDACTION_LABEL from '@salesforce/label/c.Set_To_Redaction';
import { publishToAmplitude } from 'c/amplitude';

export default class StoButtonContainer extends LightningElement {
    @api recordId;

    complete = COMPLETE_LABEL;
    createNavTask = CREATE_NAV_TASK_LABEL;
    journal = JOURNAL_LABEL;
    endDialogue = END_DIALOGUE_LABEL;
    redact = SEND_TO_REDACTION_LABEL;

    showFlow = false;
    showComplete = false;
    showRedact = false;
    showJournal = false;
    showCreateNavTask = false;
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
        if (this.label === this.complete) {
            this.showComplete = true;
            this.showRedact = false;
            this.showJournal = false;
            this.showCreateNavTask = false;
        }

        if (this.label === this.redact) {
            this.showRedact = true;
            this.showComplete = false;
            this.showJournal = false;
            this.showCreateNavTask = false;
        }

        if (this.label === this.createNavTask) {
            this.showCreateNavTask = true;
            this.showRedact = false;
            this.showComplete = false;
            this.showJournal = false;
        }

        if (this.label === this.journal) {
            this.showJournal = true;
            this.showCreateNavTask = false;
            this.showRedact = false;
            this.showComplete = false;
        }
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
    }
}

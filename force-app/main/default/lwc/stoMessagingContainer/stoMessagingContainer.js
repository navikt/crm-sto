import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import { refreshApex } from '@salesforce/apex';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import IN_QUEUE_FIELD from '@salesforce/schema/Case.CRM_In_Queue__c';
import PUT_BACK_LABEL from '@salesforce/label/c.STO_Put_Back';
import RESERVE_LABEL from '@salesforce/label/c.STO_Reserve_For_Me';
import TRANSFER_LABEL from '@salesforce/label/c.STO_Transfer';
import COMPLIETE_AND_SHARE_WITH_USER_LABEL from '@salesforce/label/c.STO_Complete_And_Share';
import JOURNAL_LABEL from '@salesforce/label/c.NKS_Journal';
import CREATE_NAV_TASK_LABEL from '@salesforce/label/c.NKS_Create_NAV_Task';
import SET_TO_REDACTION_LABEL from '@salesforce/label/c.NKS_Set_To_Redaction';
import { publishToAmplitude } from 'c/amplitude';

const CONSTANTS = {
    CREATE_NAV_TASK: 'createNavTask',
    JOURNAL: 'journal',
    FINISHED: 'FINISHED',
    FINISHED_SCREEN: 'FINISHED_SCREEN',
    THREAD: 'Thread__c',
    IN_PROGRESS: 'In progress',
    RESERVED: 'Reserved',
    FORWARDED: 'Forwarded',
    CLOSED: 'Closed',
    CASE_FIELD_API_NAME: 'CRM_Case__c'
};

export default class StoMessagingContainer extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api cardTitle = '';
    @api showClose = false;
    @api checkMedskriv = false;

    @track singleThread = true;

    showPanel = false;
    showFlow = false;
    labels = {
        reserve: RESERVE_LABEL,
        putBack: PUT_BACK_LABEL,
        transfer: TRANSFER_LABEL,
        createNavTask: CREATE_NAV_TASK_LABEL,
        journal: JOURNAL_LABEL,
        setToRedaction: SET_TO_REDACTION_LABEL,
        completeAndShare: COMPLIETE_AND_SHARE_WITH_USER_LABEL
    };
    label;
    caseId;
    wiredCase;
    status;
    closed = false;
    inQueue = false;

    connectedCallback() {
        this.getCaseId();
    }

    @wire(getRecord, { recordId: '$caseId', fields: [STATUS_FIELD, IN_QUEUE_FIELD] })
    wiredRecord(result) {
        this.wiredCase = result;
        const { data, error } = result;
        if (data) {
            this.status = getFieldValue(data, STATUS_FIELD);
            this.inQueue = getFieldValue(data, IN_QUEUE_FIELD);
        } else if (error) {
            console.log(error.body.message);
        }
    }

    getCaseId() {
        if (this.isThread) {
            getRelatedRecord({
                parentId: this.recordId,
                relationshipField: CONSTANTS.CASE_FIELD_API_NAME,
                objectApiName: this.objectApiName
            })
                .then((record) => {
                    this.caseId = this.resolve(CONSTANTS.CASE_FIELD_API_NAME, record);
                })
                .catch((error) => {
                    console.log(error);
                });
        } else {
            this.caseId = this.recordId;
        }
    }

    toggleFlow(event) {
        this.showFlow = !this.showFlow;
        if (event.target?.dataset.id) {
            this.dataId = event.target.dataset.id;
            this.changeColor(this.dataId);
        }

        if (event.target?.label) {
            this.label = event.target.label;
            publishToAmplitude('STO', { type: `${this.label} pressed` });
        }
    }

    handleFlowStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === CONSTANTS.FINISHED || flowStatus === CONSTANTS.FINISHED_SCREEN) {
            refreshApex(this.wiredCase);
            this.showFlow = false;
        }
    }

    changeColor(dataId) {
        const buttons = this.template.querySelectorAll('lightning-button');
        buttons.forEach((button) => {
            button.classList.remove('active');
        });
        let currentButton = this.template.querySelector(`lightning-button[data-id="${dataId}"]`);
        if (currentButton && this.showFlow) {
            currentButton.classList.add('active');
        }
    }

    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj);
    }

    handleSubmit() {
        if (!this.completeDisabled) {
            this.showFlow = !this.showFlow;
            publishToAmplitude('STO', { type: 'Complete/Send pressed' });
        }
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

    get isThread() {
        return this.objectApiName === CONSTANTS.THREAD;
    }

    get submitButtonLabel() {
        return this.completeDisabled ? 'Send' : this.labels.completeAndShare;
    }

    /**
     * Disabled
     */
    get completeDisabled() {
        return this.status !== CONSTANTS.IN_PROGRESS && this.status !== CONSTANTS.RESERVED;
    }

    get reserveDisabled() {
        return this.status !== CONSTANTS.IN_PROGRESS || this.status === CONSTANTS.CLOSED;
    }

    get putBackDisabled() {
        return this.status === CONSTANTS.FORWARDED || this.status === CONSTANTS.CLOSED;
    }

    get transferDisabled() {
        return !this.inQueue;
    }

    /**
     * Show Flow Condition
     */
    get showReserve() {
        return this.showFlow && this.label === this.labels.reserve;
    }

    get showPutBack() {
        return this.showFlow && this.label === this.labels.putBack;
    }

    get showTransfer() {
        return this.showFlow && this.label === this.labels.transfer;
    }

    get showRedact() {
        return this.showFlow && this.label === this.labels.setToRedaction;
    }

    get showCreateNavTask() {
        return this.showFlow && this.dataId === CONSTANTS.CREATE_NAV_TASK;
    }

    get showJournal() {
        return this.showFlow && this.dataId === CONSTANTS.JOURNAL;
    }

    get showComplete() {
        return this.showFlow && this.submitButtonLabel === this.labels.completeAndShare;
    }

    /**
     * Aria Expanded
     */
    get createNavTaskExpanded() {
        return this.showCreateNavTask.toString();
    }

    get journalExpanded() {
        return this.showJournal.toString();
    }

    get reserveExpanded() {
        return this.showReserve.toString();
    }

    get putBackExpanded() {
        return this.showPutBack.toString();
    }

    get transferExpanded() {
        return this.showTransfer.toString();
    }

    get redactExpanded() {
        return this.showRedact.toString();
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

    handleModalStatusChange(event) {
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

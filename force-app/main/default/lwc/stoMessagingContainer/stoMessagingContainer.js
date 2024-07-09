import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/STO_RecordInfoController.getRelatedRecord';
import { refreshApex } from '@salesforce/apex';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import IN_QUEUE_FIELD from '@salesforce/schema/Case.CRM_In_Queue__c';
import PUT_BACK_LABEL from '@salesforce/label/c.STO_Put_Back';
import RESERVE_LABEL from '@salesforce/label/c.STO_Reserve_For_Me';
import TRANSFER_LABEL from '@salesforce/label/c.STO_Transfer';
import SHARE_WITH_USER_LABEL from '@salesforce/label/c.STO_Share_With_User';
import JOURNAL_LABEL from '@salesforce/label/c.NKS_Journal';
import CREATE_NAV_TASK_LABEL from '@salesforce/label/c.NKS_Create_NAV_Task';
import SET_TO_REDACTION_LABEL from '@salesforce/label/c.NKS_Set_To_Redaction';
import { publishToAmplitude } from 'c/amplitude';
import { handleShowNotifications } from 'c/nksComponentsUtils';

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

    caseId;
    wiredCase;
    label;
    status;
    inQueue = false;
    showComplete = false;
    showReserveButton = false;
    showPutBackButton = false;
    showTransferButton = false;
    showRedactButton = false;
    showJournalButton = false;
    showCreateNavTaskButton = false;

    labels = {
        RESERVE_LABEL,
        PUT_BACK_LABEL,
        TRANSFER_LABEL,
        CREATE_NAV_TASK_LABEL,
        JOURNAL_LABEL,
        SET_TO_REDACTION_LABEL,
        SHARE_WITH_USER_LABEL
    };

    connectedCallback() {
        this.initializeCaseId();
    }

    @wire(getRecord, { recordId: '$caseId', fields: [STATUS_FIELD, IN_QUEUE_FIELD] })
    wiredRecord(result) {
        this.wiredCase = result;
        const { data, error } = result;
        if (data) {
            this.status = getFieldValue(data, STATUS_FIELD);
            this.inQueue = getFieldValue(data, IN_QUEUE_FIELD);
        } else if (error) {
            console.error(error.body.message);
        }
    }

    get inputVariables() {
        return [{ name: 'recordId', type: 'String', value: this.recordId }];
    }

    get isThread() {
        return this.objectApiName === CONSTANTS.THREAD;
    }

    get topButtonConfigs() {
        return [
            {
                id: 'reserve',
                label: this.labels.RESERVE_LABEL,
                disabled: this.reserveDisabled,
                onclick: this.toggleButton.bind(this, 'Reserve'),
                expanded: this.showReserveButton.toString()
            },
            {
                id: 'conditional',
                label: this.isThread ? this.labels.TRANSFER_LABEL : this.labels.PUT_BACK_LABEL,
                disabled: this.isThread ? this.transferDisabled : this.putBackDisabled,
                onclick: this.isThread
                    ? this.toggleButton.bind(this, 'Transfer')
                    : this.toggleButton.bind(this, 'PutBack'),
                expanded: this.isThread ? this.showTransferButton.toString() : this.showPutBackButton.toString()
            },
            {
                id: 'redact',
                label: this.labels.SET_TO_REDACTION_LABEL,
                disabled: false,
                onclick: this.toggleButton.bind(this, 'Redact'),
                expanded: this.showRedactButton.toString()
            }
        ];
    }

    get bottomButtonConfigs() {
        return [
            {
                id: 'journal',
                label: this.labels.JOURNAL_LABEL,
                onclick: this.toggleButton.bind(this, 'Journal'),
                expanded: this.showJournalButton.toString()
            },
            {
                id: 'createNavTask',
                label: this.labels.CREATE_NAV_TASK_LABEL,
                onclick: this.toggleButton.bind(this, 'CreateNavTask'),
                expanded: this.showCreateNavTaskButton.toString()
            }
        ];
    }

    get topFlowConfigs() {
        return [
            {
                id: 'reserve',
                condition: this.showReserveButton,
                flowApiName: 'Case_STO_Reserve_v_2'
            },
            {
                id: 'putBack',
                condition: this.showPutBackButton,
                flowApiName: 'Case_STO_Put_Back'
            },
            {
                id: 'transfer',
                condition: this.showTransferButton,
                flowApiName: 'STO_Transfer_v_2'
            },
            {
                id: 'redact',
                condition: this.showRedactButton,
                flowApiName: 'Case_STO_Redact_v_2'
            }
        ];
    }

    get bottomFlowConfigs() {
        return [
            {
                id: 'journal',
                condition: this.showJournalButton,
                flowApiName: 'Case_STO_Journal_v_2',
                handleStatusChange: this.handleFlowStatusChange
            },
            {
                id: 'createNavTask',
                condition: this.showCreateNavTaskButton,
                flowApiName: 'Case_STO_Send_NAV_Task_v_2',
                handleStatusChange: this.handleFlowStatusChange
            },
            {
                id: 'complete',
                condition: this.showComplete,
                flowApiName: 'Case_STO_Complete_v_2',
                handleStatusChange: this.handleSubmitStatusChange
            }
        ];
    }

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

    get notificationBoxTemplate() {
        return this.template.querySelector('c-nks-notification-box');
    }

    initializeCaseId() {
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
                    console.error(error);
                });
        } else {
            this.caseId = this.recordId;
        }
    }

    toggleButton(buttonName, event) {
        this.label = event.target?.label;
        const buttons = ['Reserve', 'PutBack', 'Transfer', 'Journal', 'CreateNavTask', 'Redact'];
        buttons.forEach((button) => {
            this[`show${button}Button`] = button === buttonName ? !this[`show${button}Button`] : false;
        });
    }

    resetButtonVisibility() {
        [
            'showReserveButton',
            'showPutBackButton',
            'showTransferButton',
            'showRedactButton',
            'showJournalButton',
            'showCreateNavTaskButton'
        ].forEach((state) => {
            this[state] = false;
        });
    }

    handleFlowStatusChange(event) {
        const { status, outputVariables, flowTitle } = event.detail;
        if (status === CONSTANTS.FINISHED || status === CONSTANTS.FINISHED_SCREEN) {
            refreshApex(this.wiredCase);
            this.resetButtonVisibility();
            publishToAmplitude('STO', { type: `${this.label} pressed` });
            handleShowNotifications(flowTitle, outputVariables, this.notificationBoxTemplate);
        }
    }

    handleSubmit() {
        if (!this.completeDisabled) {
            this.resetButtonVisibility();
            this.showComplete = !this.showComplete;
        }
    }

    handleSubmitStatusChange(event) {
        const flowStatus = event.detail.status;
        if (flowStatus === CONSTANTS.FINISHED || flowStatus === CONSTANTS.FINISHED_SCREEN) {
            refreshApex(this.wiredCase);
            this.showComplete = false;
            publishToAmplitude('STO', { type: 'Complete/Send pressed' });
        }
    }

    resolve(path, obj) {
        return path.split('.').reduce((prev, curr) => (prev ? prev[curr] : null), obj);
    }
}

import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { publishToAmplitude } from 'c/amplitude';

export default class ThreadExpandedTimeline extends NavigationMixin(LightningElement) {
    @api recordId;
    @api logEvent;
    messages;
    hasMessages = false;
    error;

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Messages__r',
        fields: [
            'Message__c.Id',
            'Message__c.CRM_Message_Text__c',
            'Message__c.CRM_Type__c',
            'Message__c.CRM_Event_Type__c',
            'Message__c.CRM_Sent_date__c',
            'Message__c.CRM_From_User__c',
            'Message__c.CRM_From_Contact__c',
            'Message__c.CRM_From_First_Name__c',
            'Message__c.CRM_External_Message__c',
            'Message__c.CRM_From_Label__c'
        ],
        sortBy: ['Message__c.CRM_Sent_date__c']
    })
    wiredMessages(result) {
        if (result.error) {
            this.error = result.error;
            console.log('Error: ' + JSON.stringify(result.error, null, 2));
        } else if (result.data) {
            this.messages = result.data.records.map((record) => {
                const retObj = {};
                Object.keys(record.fields).forEach((field) => {
                    retObj[field] = record.fields[field].value;
                });
                return retObj;
            });
            this.hasMessages = true;
        }
    }

    openRecord(event) {
        event.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Conversation_note__c',
                actionName: 'view'
            }
        });
        if (this.logEvent) {
            publishToAmplitude('Timeline', { type: 'Navigate to record' });
        }
    }

    handlePrint() {
        console.log(this.recordId);
        if (!this.recordId) {
            console.error('No record ID found!');
            return;
        }
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__webPage',
            attributes: {
                url: `/apex/NKS_RecordPrint?id=${this.recordId}`
            }
        }).then((url) => {
            console.log('Opening URL:', url);
            window.open(url, '_self');
        });
    }
}

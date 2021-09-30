import { LightningElement, api, wire } from 'lwc';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import { loadStyle } from 'lightning/platformResourceLoader';
import markasread from '@salesforce/apex/CRM_MessageHelper.markAsRead';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/Conversation_Note__c.Name';
import NOTE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Conversation_Note__c';

const fields = [NAME_FIELD, NOTE_FIELD]; //Extract the name of the thread record

export default class CommunityConversationNote extends LightningElement {
    @api recordId; 
    @api title; 

    connectedCallback() {
        loadStyle(this, dekoratoren);
        //TODO: change markasread 
        markasread({ threadId: this.recordId });
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    conversationnote;
    get name() {
        return getFieldValue(this.conversationnote.data, NAME_FIELD);
    }
    get note() {
        return getFieldValue(this.conversationnote.data, NOTE_FIELD);
    }
}

//TODO: create markasread function on conversation note 
/*@AuraEnabled
public static void markAsRead(Id threadId) {
    List<Message__c> msgList = [SELECT Id FROM Message__c WHERE CRM_Read__c = FALSE AND CRM_Thread__c = :threadId];
    for (Message__c msg : msgList) {
        msg.CRM_Read__c = true;
        msg.CRM_Read_Datetime__c = DateTime.now();
    }
    update msgList;
}*/

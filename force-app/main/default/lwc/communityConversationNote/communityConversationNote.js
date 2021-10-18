import { LightningElement, api, wire } from 'lwc';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import veiledericon from '@salesforce/resourceUrl/female';
import { loadStyle } from 'lightning/platformResourceLoader';
import markasread from '@salesforce/apex/stoInboxHelper.markAsRead';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import NAME_FIELD from '@salesforce/schema/Conversation_Note__c.Name';
import NOTE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Conversation_Note__c';
import DATE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Registered_Datetime_Formula__c';


const fields = [NAME_FIELD, NOTE_FIELD, DATE_FIELD]; //Extract the name of the thread record

export default class CommunityConversationNote extends LightningElement {
    @api recordId; 
    @api title; 

    get navIcon() {
        return veiledericon;
    }

    connectedCallback() {
        loadStyle(this, dekoratoren);
        markasread({ conversationNoteId: this.recordId });
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    conversationnote;
    get name() {
        return getFieldValue(this.conversationnote.data, NAME_FIELD);
    }
    get note() {
        return getFieldValue(this.conversationnote.data, NOTE_FIELD);
    }
    get date() {
        return getFieldValue(this.conversationnote.data, DATE_FIELD);
    }
}

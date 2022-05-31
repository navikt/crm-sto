import { LightningElement, api, wire } from 'lwc';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import veiledericon from '@salesforce/resourceUrl/female';
import { loadStyle } from 'lightning/platformResourceLoader';
import markasread from '@salesforce/apex/stoInboxHelper.markAsRead';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getRelatedConversations from '@salesforce/apex/relatedConversationNoteHelper.getRelatedConversations';

import NAME_FIELD from '@salesforce/schema/Conversation_Note__c.Name';
import NOTE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Conversation_Note__c';
import DATE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Registered_Datetime_Formula__c';
import BEHANDLINGSKJEDE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Henvendelse_BehandlingskjedeId__c';
import BEHANDLINGSID_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_Henvendelse_BehandlingsId__c';
import APIREFERENCE_FIELD from '@salesforce/schema/Conversation_Note__c.CRM_API_Reference__c';

const fields = [NAME_FIELD, NOTE_FIELD, DATE_FIELD, BEHANDLINGSKJEDE_FIELD, BEHANDLINGSID_FIELD, APIREFERENCE_FIELD]; //Extract the name of the thread record

export default class CommunityConversationNote extends LightningElement {
    @api recordId;
    @api title;
    name;
    note;
    date;
    relatedNotes;

    get navIcon() {
        return veiledericon;
    }

    connectedCallback() {
        loadStyle(this, dekoratoren);
        markasread({ conversationNoteId: this.recordId });
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    wireData({ error, data }) {
        if (data) {
            this.name = getFieldValue(data, NAME_FIELD);
            this.note = getFieldValue(data, NOTE_FIELD);
            this.date = getFieldValue(data, DATE_FIELD);
            const behandlingskjede = getFieldValue(data, BEHANDLINGSKJEDE_FIELD);
            const behandlingsId = getFieldValue(data, BEHANDLINGSID_FIELD);
            const apiRef = getFieldValue(data, APIREFERENCE_FIELD);
            getRelatedConversations({
                behandlingskjede: behandlingskjede,
                behandlingsId: behandlingsId,
                apiRef: apiRef
            })
                .then((conv) => {
                    this.relatedNotes = conv;
                })
                .catch((err) => console.log(err));
        }
        if (error) {
            console.log(error);
        }
    }

    get showRelatedNotes() {
        return this.relatedNotes && this.relatedNotes.length > 0;
    }
}

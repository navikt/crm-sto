import { LightningElement, wire } from 'lwc';
import getNotes from '@salesforce/apex/stoInboxHelper.getNotesByBehandlingskjedeId';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

export default class CommunityConversationNoteViewer extends LightningElement {
    kjedeId;
    convNotes;

    //Get all conversation notes with matching behandlingskjedeid
    @wire(getRecord, { recordId: '$recordId', fields })
    convoteCallback({ error, data }) {
        if (data) {
            this.kjedeId = data;
        } else if (error) {
        }
    }

    //Get all conversation notes with matching behandlingskjedeid
    @wire(getRecord, { kjedeId: '$kjedeId' })
    wireNotes({ error, data }) {
        if (data) {
            this.convNotes = data;
        } else if (error) {
            console.log('Something went wrong');
        }
    }
}

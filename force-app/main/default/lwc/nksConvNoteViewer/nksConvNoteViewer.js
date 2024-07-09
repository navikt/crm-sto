import { LightningElement, api, wire } from 'lwc';
import getconvnote from '@salesforce/apex/NKS_DialogueViewController.getConvNote';
import { resolve } from 'c/nksComponentsUtils';

export default class NksConvNoteViewer extends LightningElement {
    @api recordId;

    conversationNote;
    error = false;

    @wire(getconvnote, { convNoteId: '$recordId' }) //Calls apex and gets conversation note record
    wireNotes(result) {
        if (result.error) {
            this.error = true;
            console.log('Error: ' + JSON.stringify(this.error, null, 2));
        } else if (result.data) {
            this.conversationNote = result.data[0];
        }
    }

    get isLoading() {
        return !this.conversationNote && this.error === false;
    }

    get convNoteTheme() {
        return this.conversationNote ? resolve('CRM_Theme__r.Name', this.conversationNote) : '';
    }
}

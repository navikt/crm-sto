import { LightningElement, api, wire } from 'lwc';
import getconvnote from '@salesforce/apex/NKS_DialogueViewController.getConvNote';

export default class DiaConvNoteViewer extends LightningElement {
    @api recordId;

    conversationNote;
    error = false;

    @wire(getconvnote, { convNoteId: '$recordId' }) //Calls apex and gets conversation note record
    wireNotes(result) {
        if (result.error) {
            this.error = true;
            console.log('Error: ' + JSON.stringify(error, null, 2));
        } else if (result.data) {
            this.conversationNote = result.data[0];
        }
    }

    get isLoading() {
        return !this.conversationNote && this.error === false;
    }

    get convNoteTheme() {
        return this.conversationNote ? this.resolve('CRM_Theme__r.Name', this.conversationNote) : '';
    }

    /**
     * Retrieves the value from the given object's data path
     * @param {data path} path
     * @param {JS object} obj
     */
    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj || self);
    }
}

import { LightningElement, api, wire } from 'lwc';
import veiledericon from '@salesforce/resourceUrl/female';
import markasread from '@salesforce/apex/stoInboxHelper.markAsRead';
import getRelatedConversations from '@salesforce/apex/relatedConversationNoteHelper.getRelatedConversations';
import getConvNote from '@salesforce/apex/NKS_DialogueViewController.getConvNote';
import { setDecoratorParams } from 'c/inboxAmplitude';

export default class CommunityConversationNote extends LightningElement {
    @api recordId;
    @api title;

    name;
    note;
    date;
    relatedNotes;
    themeGroup;
    record;

    get navIcon() {
        return veiledericon;
    }

    connectedCallback() {
        markasread({ conversationNoteId: this.recordId });
    }

    @wire(getConvNote, { convNoteId: '$recordId' })
    wiredConvNotes(result) {
        const { error, data } = result;
        if (error) {
            console.error('Problem getting conversation note: ', error);
        } else if (data) {
            this.record = data[0];
            this.name = this.record.Name;
            this.note = this.record.CRM_Conversation_Note__c;
            this.date = this.record.CRM_Registered_Datetime_Formula__c;
            this.themeGroup = this.record.CRM_Theme_Group_Name__c;
            const behandlingskjede = this.record.CRM_Henvendelse_BehandlingskjedeId__c;
            const behandlingsId = this.record.CRM_Henvendelse_BehandlingsId__c;
            const apiRef = this.record.CRM_API_Reference__c;
            setDecoratorParams('Samtalereferat', 'Samtalereferat', this.themeGroup);
            getRelatedConversations({
                behandlingskjede: behandlingskjede,
                behandlingsId: behandlingsId,
                apiRef: apiRef
            })
                .then((conv) => {
                    this.relatedNotes = conv;
                })
                .catch((err) => console.error('Problem getting related conversation notes: ', err));
        }
    }

    get showRelatedNotes() {
        return this.relatedNotes && this.relatedNotes.length > 0;
    }
}

import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CommunityConversationNoteRelatedItem extends NavigationMixin(LightningElement) {
    @api note;
    url;

    connectedCallback() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.note.Id,
                objectApiName: 'Conversation_Note__c',
                actionName: 'view'
            }
        }).then((url) => {
            this.url = url;
        });
    }

    get date() {
        return this.note.CRM_Date_Registered__c
            ? ' - ' + this.note.CRM_Date_Registered__c.split('-').reverse().join('.')
            : '';
    }

    get label() {
        return (
            (this.note.CRM_Theme__r.Name ? this.note.CRM_Theme__r.Name + ' - ' : '') +
            'Klikk her for å se relaterte samtalereferat på samme sak' +
            this.date
        );
    }
}

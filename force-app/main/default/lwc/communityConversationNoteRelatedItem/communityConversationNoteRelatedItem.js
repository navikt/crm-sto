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
}

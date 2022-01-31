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
        if (this.note.CRM_Date_Time_Registered__c) {
            const inputs = this.note.CRM_Date_Time_Registered__c.split('T');
            const dateTable = inputs[0].split('-');
            const timeTable = inputs[1].split(':');

            const fullDate = new Date(Date.UTC(dateTable[0], dateTable[1], dateTable[2], timeTable[0], timeTable[1]));
            return ' - ' + new Intl.DateTimeFormat('no-no', { dateStyle: 'long', timeStyle: 'short' }).format(fullDate);
        } else {
            return '';
        }
    }

    get label() {
        return (
            (this.note.CRM_Theme__r?.Name ? this.note.CRM_Theme__r.Name + ' - ' : '') +
            'Klikk her for å se relaterte samtalereferat på samme sak' +
            this.date
        );
    }
}

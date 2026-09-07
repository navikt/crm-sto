import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class CommunityConversationNoteRelatedItem extends NavigationMixin(LightningElement) {
    @api note;

    url;
    _lastNoteId;

    renderedCallback() {
        const currentId = this.note?.Id;
        if (!currentId || currentId === this._lastNoteId) {
            return;
        }

        this._lastNoteId = currentId;

        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: currentId,
                objectApiName: 'Conversation_Note__c',
                actionName: 'view'
            }
        })
            .then((url) => {
                this.url = url;
            })
            .catch((e) => {
                this.url = undefined;
                console.error(e);
            });
    }

    get date() {
        if (this.note?.CRM_Date_Time_Registered__c) {
            const inputs = this.note.CRM_Date_Time_Registered__c.split('T');
            const dateTable = inputs[0].split('-');
            const timeTable = inputs[1].split(':');

            const fullDate = new Date(
                Date.UTC(dateTable[0], dateTable[1] - 1, dateTable[2], timeTable[0], timeTable[1])
            );
            return (
                ' fra ' + new Intl.DateTimeFormat('no-no', { dateStyle: 'long', timeStyle: 'short' }).format(fullDate)
            );
        }
        return '';
    }

    get label() {
        return 'Referat' + this.date;
    }
}

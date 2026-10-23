import { LightningElement, api, wire } from 'lwc';
import getReplyContext from '@salesforce/apex/stoHelperClass.getReplyContext';

export default class StoInboxCloseItem extends LightningElement {
    @api thread;
    @api index;
    canClose = false;
    accessError;

    get threadId() {
        return this.thread?.recordId;
    }

    @wire(getReplyContext, { threadId: '$threadId' })
    wiredReplyContext({ data, error }) {
        this.canClose = data?.canReply === true;
        this.accessError = error
            ? 'Vi kunne ikke hente hvem som kan avslutte samtalen. Oppdater siden og prøv på nytt.'
            : undefined;
        if (error) console.error('Problem getting close access:', error);
    }

    handleClick() {
        if (!this.canClose) return;
        this.refs.childRef.openModal();
    }

    handleCloseThread() {
        if (!this.canClose) return;
        this.dispatchEvent(
            new CustomEvent('closethread', {
                detail: this.index
            })
        );
    }
}

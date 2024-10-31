import { LightningElement } from 'lwc';
import startFromComponent from '@salesforce/apex/nksJournalFeilregistrertQueueable.startFromComponent';
import getRemainingCount from '@salesforce/apex/nksJournalFeilregistrertQueueable.getRemainingCount';

export default class NksJournalFeilregistert extends LightningElement {
    disabled = false;
    statusText;
    remainingCount;

    connectedCallback() {
        this.updateTotal();
    }

    startJournalRerun() {
        if (this.disabled) {
            return;
        }
        this.disabled = true;

        const suffix = this.refs.suffix?.value;
        const filter = this.refs.filter?.value;
        startFromComponent({
            externalReferenceSuffix: suffix,
            filterQuery: filter
        })
            .then(() => {
                this.statusText = 'Rerun started';
            })
            .catch((e) => {
                this.statusText = 'Rerun failed. ' + JSON.stringify(e);
            })
            .finally(() => {
                this.updateTotal();
            });
    }

    updateTotal() {
        getRemainingCount()
            .then((count) => {
                this.remainingCount = count;
            })
            .catch((e) => {
                this.statusText = 'Could not get remaing count. ' + JSON.stringify(e);
            })
            .finally(() => {
                this.disabled = false;
            });
    }
}

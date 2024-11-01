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
        const limit = this.refs.limit?.value;
        this.statusText = 'Rerun started';
        startFromComponent({
            externalReferenceSuffix: suffix,
            wantedLimit: limit
        })
            .then(() => {
                this.statusText = 'Rerun completed';
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

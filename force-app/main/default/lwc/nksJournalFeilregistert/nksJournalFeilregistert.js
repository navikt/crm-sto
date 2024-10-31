import { LightningElement } from 'lwc';
import startFromComponent from '@salesforce/apex/nksJournalFeilregistrertQueueable.startFromComponent';

export default class NksJournalFeilregistert extends LightningElement {
    disabled = false;
    statusText;

    startJournalRerun() {
        if (this.disabled) {
            return;
        }
        this.disabled = true;

        const suffix = this.refs.suffix?.value;
        const filter = this.refs.filter?.value;
        startFromComponent({
            externalReferenceSuffix: suffix,
            queryFilter: filter
        })
            .then(() => {
                this.statusText = 'Rerun started';
            })
            .catch(() => {
                this.statusText = 'Rerun failed';
            });
    }
}

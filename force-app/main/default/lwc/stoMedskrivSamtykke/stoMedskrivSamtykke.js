import { getFieldValue, getRecord, updateRecord } from 'lightning/uiRecordApi';
import { LightningElement, api, wire } from 'lwc';
import MEDSKRIV_FIELD from '@salesforce/schema/Thread__c.CRM_Medskriv__c';
import ID_FIELD from '@salesforce/schema/Thread__c.Id';

const titlesConst = {
    false: 'Du har godkjent at denne samtalen kan brukes til opplæring av ansatte i NAV.',
    true: 'Godkjenningen din ble fjernet.'
};

const textConst = {
    false:
        'For å lære opp nye veiledere og utvikle oss kan vi noen ganger være to personer som ser og svarer på meldingen din. Personen som ser samtalen på grunn av opplæring eller utvikling har også taushetsplikt. Du kan når som helst trekke tilbake godkjenningen.',
    true: 'Vi vil ikke bruke samtalen din til å lære opp veildere i NAV.'
};

export default class StoMedskrivSamtykke extends LightningElement {
    @api recordId;
    buttonPushed = false;

    revokeMedskriv(e) {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[MEDSKRIV_FIELD.fieldApiName] = false;

        const recordInput = { fields };
        setTimeout(() => (this.buttonPushed = true), 100);

        updateRecord(recordInput)
            .then((a) => {
                console.log('Updated');
                console.log(a);
            })
            .catch(() => {
                console.log('Tester');
            });
    }

    @wire(getRecord, { recordId: '$recordId', fields: MEDSKRIV_FIELD })
    thread;

    get medskriv() {
        return getFieldValue(this.thread.data, MEDSKRIV_FIELD);
    }

    get showPanel() {
        return this.medskriv || this.buttonPushed;
    }

    get text() {
        return textConst[this.buttonPushed];
    }

    get title() {
        return titlesConst[this.buttonPushed];
    }

    get btnClasses() {
        return this.buttonPushed ? 'slds-hide' : '';
    }
}

import { getFieldValue, getRecord, updateRecord } from 'lightning/uiRecordApi';
import { LightningElement, api, wire } from 'lwc';
import MEDSKRIV_FIELD from '@salesforce/schema/Thread__c.STO_Medskriv__c';
import ID_FIELD from '@salesforce/schema/Thread__c.Id';
import THREAD_NAME_FIELD from '@salesforce/schema/Thread__c.STO_ExternalName__c';
import LoggerUtility from 'c/loggerUtility';
import { AnalyticsEvents, logButtonEvent, getComponentName } from 'c/inboxAmplitude';
import { getContentType } from 'c/stoUtils';

const titlesConst = {
    false: 'Du har godkjent at denne samtalen kan brukes til opplæring av ansatte i Nav.',
    true: 'Godkjenningen din ble fjernet.'
};

const textConst = {
    false: 'For å lære opp nye veiledere og utvikle oss kan vi noen ganger være to personer som ser og svarer på meldingen din. Personen som ser samtalen på grunn av opplæring eller utvikling har også taushetsplikt. Du kan når som helst trekke tilbake godkjenningen.',
    true: 'Vi vil ikke bruke samtalen din til å lære opp veiledere i Nav.'
};

export default class StoMedskrivSamtykke extends LightningElement {
    @api recordId;
    buttonPushed = false;

    revokeMedskriv() {
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[MEDSKRIV_FIELD.fieldApiName] = false;

        const recordInput = { fields };
        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
        setTimeout(() => (this.buttonPushed = true), 100);

        updateRecord(recordInput).catch((error) => {
            LoggerUtility.logError('NKS', 'STO', error, 'Kunne ikke fjerne medskriv', this.recordId);
        });

        logButtonEvent(
            AnalyticsEvents.FORM_COMPLETED,
            'Fjern min godkjenning',
            getContentType(this.threadExternalName),
            getComponentName('StoMedskrivSamtykke'),
            'medskriv'
        );
    }

    @wire(getRecord, { recordId: '$recordId', fields: [MEDSKRIV_FIELD, THREAD_NAME_FIELD] })
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

    get threadExternalName() {
        return getFieldValue(this.thread.data, THREAD_NAME_FIELD);
    }
}

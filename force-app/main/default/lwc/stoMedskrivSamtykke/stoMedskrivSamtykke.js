import { updateRecord } from 'lightning/uiRecordApi';
import { LightningElement, api, wire } from 'lwc';
import MEDSKRIV_FIELD from '@salesforce/schema/Thread__c.STO_Medskriv__c';
import ID_FIELD from '@salesforce/schema/Thread__c.Id';
import LoggerUtility from 'c/loggerUtility';
import { AnalyticsEvents, logButtonEvent, getComponentName, setDecoratorParams } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

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
    pageType;
    stoPageTheme;

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
            getComponentName(this.template),
            'medskriv'
        );
    }

    @wire(getThread, { recordId: '$recordId' })
    wiredThread(result) {
        const { data, error } = result;

        if (data) {
            this.medskriv = data.STO_Medskriv__c;
            this.pageType = data.CRM_Thread_Type__c;
            this.stoPageTheme = data.STO_Category_Formula__c;

            if (this.pageType && this.stoPageTheme) {
                setDecoratorParams(this.pageType, this.pageTheme);
            }
        } else if (error) {
            console.error(error);
        }
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

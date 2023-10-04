import { LightningElement, api, wire, track } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import getRelatedRecord from '@salesforce/apex/NksRecordInfoController.getRelatedRecord';
import FULL_NAME_FIELD from '@salesforce/schema/Person__c.CRM_FullName__c';
import PERSON_IDENT_FIELD from '@salesforce/schema/Person__c.Name';
import GENDER_FIELD from '@salesforce/schema/Person__c.INT_Sex__c';
import AGE_FIELD from '@salesforce/schema/Person__c.CRM_Age__c';
import CITIZENSHIP_FIELD from '@salesforce/schema/Person__c.INT_Citizenships__c';
import MARITAL_STATUS_FIELD from '@salesforce/schema/Person__c.INT_MaritalStatus__c';
import NAV_ICONS from '@salesforce/resourceUrl/NKS_navIcons';
import getHistorikk from '@salesforce/apex/NKS_HistorikkViewController.getHistorikk';
import getNavUnit from '@salesforce/apex/NKS_NavUnitSingleController.findUnit';
import getNavLinks from '@salesforce/apex/NKS_NavUnitLinks.getNavLinks';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { MessageContext, APPLICATION_SCOPE, subscribe, unsubscribe } from 'lightning/messageService';
import nksVeilederName from '@salesforce/messageChannel/nksVeilderName__c';
import { logAmplitudeEvent } from 'c/nksAmplitudeUtils';
import getUserDepartment from '@salesforce/apex/NKS_AmplitudeHelper.getUserDepartment';

export default class NksPersonHeader extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api relationshipField;
    @api showPersonBadges = false;
    @api leftAlignBadges = false;
    @api showExtraInfo = false;
    @api condition1; //deprecated
    @api condition2; //deprecated
    personId;
    fullName;
    personIdent;
    gender;
    age;
    citizenship;
    maritalStatus;
    wireFields;
    navUnit;
    formattedUnitLink;
    department;

    @api btnClick = false;
    @api btnShowFullmakt = false;
    @api fullmaktHistData;

    @track customclass = 'grey-icon';
    @track veilederName;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        getUserDepartment().then((result) => {
            this.department = result;
        });

        this.wireFields = [this.objectApiName + '.Id'];
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    // Encapsulate logic for Lightning message service subscribe and unsubsubscribe
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                nksVeilederName,
                (message) => this.handleVeilderName(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    // Handler for message received by component
    handleVeilderName(message) {
        if (message.recordId === this.recordId) {
            this.veilederName = message.displayName;
            this.veilederIdent = message.ident;
        }
    }

    get showNotifications() {
        return this.notifications.length > 0;
    }

    get showErrors() {
        return this.errorMessages.length > 0;
    }

    get genderIcon() {
        switch (this.gender) {
            case 'Mann':
                return 'MaleFilled';
            case 'Kvinne':
                return 'FemaleFilled';
        }
        return 'NeutralFilled';
    }

    get genderIconSrc() {
        return NAV_ICONS + '/' + this.genderIcon + '.svg#' + this.genderIcon;
    }

    get genderIconClass() {
        return this.genderIcon;
    }

    get formattedUnit() {
        return this.navUnit ? `${this.navUnit.enhetNr} ${this.navUnit.navn}` : '';
    }

    async getFormattedLink() {
        if (this.navUnit) {
            const link = await getNavLinks().then((list) => {
                const onlineCheck = list.find((unit) => unit.enhetNr === this.navUnit.unitNr);
                if (onlineCheck !== undefined) return 'https://www.nav.no' + onlineCheck.path;
                return (
                    'https://www.nav.no/kontor/' +
                    this.navUnit.navn
                        .replace(/\.\s/g, '.')
                        .replace(/[\s/]/g, '-')
                        .normalize('NFD')
                        .replace(/[\u0300-\u036f]/g, '')
                );
            });
            this.formattedUnitLink = link;
        }
    }

    get formattedVeilder() {
        return 'Veileder: ' + this.veilederName + (this.veilederIdent ? '(' + this.veilederIdent + ')' : '');
    }

    get showNavUnit() {
        return this.showExtraInfo && this.formattedUnit;
    }

    get formattedPersonInfo() {
        return [this.age, this.citizenship, this.maritalStatus].filter((x) => x != null).join(' / ');
    }

    get showVeilederName() {
        return this.showExtraInfo && this.veilederName;
    }

    get badgeClass() {
        return (this.leftAlignBadges ? '' : 'slds-grow ') + 'slds-var-p-right_small';
    }

    handleCopy(event) {
        const hiddenInput = document.createElement('input');
        const eventValue = event.currentTarget.value;
        hiddenInput.value = eventValue;
        document.body.appendChild(hiddenInput);
        hiddenInput.focus();
        hiddenInput.select();
        try {
            const successful = document.execCommand('copy');
            if (!successful) this.showCopyToast('error');
        } catch (error) {
            this.showCopyToast('error');
        }
        document.body.removeChild(hiddenInput);
        logAmplitudeEvent('Test Event', { type: 'Copy of personIdent', department: this.department });
    }

    showCopyToast(status) {
        const evt = new ShowToastEvent({
            message: status === 'success' ? 'kopiert til utklippstavlen.' : 'Kunne ikke kopiere',
            variant: status,
            mode: 'pester'
        });
        this.dispatchEvent(evt);
    }

    getRelatedRecordId(relationshipField, objectApiName) {
        getRelatedRecord({
            parentId: this.recordId,
            relationshipField: relationshipField,
            objectApiName: objectApiName
        })
            .then((record) => {
                this.personId = this.resolve(relationshipField, record);
            })
            .catch((error) => {
                console.log(error);
            });
    }

    @wire(getRecord, {
        recordId: '$personId',
        fields: [FULL_NAME_FIELD, PERSON_IDENT_FIELD, GENDER_FIELD, AGE_FIELD, CITIZENSHIP_FIELD, MARITAL_STATUS_FIELD]
    })
    wiredPersonInfo({ error, data }) {
        if (data) {
            this.fullName = getFieldValue(data, FULL_NAME_FIELD);
            this.personIdent = getFieldValue(data, PERSON_IDENT_FIELD);
            this.gender = getFieldValue(data, GENDER_FIELD);
            this.age = getFieldValue(data, AGE_FIELD);
            let __citizenship = getFieldValue(data, CITIZENSHIP_FIELD).toLowerCase();
            this.citizenship = __citizenship.charAt(0).toUpperCase() + __citizenship.slice(1);
            let __maritalStatus = getFieldValue(data, MARITAL_STATUS_FIELD)
                .toLowerCase()
                .replace(/_/g, ' ')
                .replace(' eller enkemann', '/-mann');
            this.maritalStatus = __maritalStatus.charAt(0).toUpperCase() + __maritalStatus.slice(1);
        }
        if (error) {
            console.log(error);
        }
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$wireFields'
    })
    wiredRecordInfo({ error, data }) {
        if (data) {
            if (this.relationshipField && this.objectApiName) {
                this.getRelatedRecordId(this.relationshipField, this.objectApiName);
            }
        }
        if (error) {
            console.log(error);
        }
    }

    @wire(getNavUnit, {
        field: '$relationshipField',
        parentObject: '$objectApiName',
        parentRecordId: '$recordId',
        type: 'PERSON_LOCATION'
    })
    wiredData(result) {
        const { data, error } = result;
        if (data) {
            this.navUnit = data.unit;
            this.getFormattedLink();
        }
        if (error) {
            console.log(`error: ${error}`);
        }
    }

    /*
     * To change the button color on click
     */
    handleFullmaktData() {
        if (!this.btnClick) {
            this.btnClick = true;
            this.customclass = 'blue-icon';
        } else if (this.btnClick) {
            this.btnClick = false;
            this.customclass = 'grey-icon';
        }
    }

    @wire(getHistorikk, {
        recordId: '$recordId',
        objectApiName: '$objectApiName'
    })
    wiredHistorikk({ error, data }) {
        if (data) {
            this.fullmaktHistData = data;
            this.btnShowFullmakt = this.fullmaktHistData.length > 0;
        }
        if (error) {
            console.log(error);
        }
    }

    /**
     * Retrieves the value from the given object's data path
     * @param {data path} path
     * @param {JS object} obj
     */
    resolve(path, obj) {
        return path.split('.').reduce(function (prev, curr) {
            return prev ? prev[curr] : null;
        }, obj || self);
    }
}

import { LightningElement } from 'lwc';
import PlusCircle from '@salesforce/resourceUrl/PlusCircle';
import LoggerUtility from 'c/loggerUtility';
import createNavTask from '@salesforce/apex/NKS_FedrekvotesakenController.createNavTask';
import hasExistingNavTasks from '@salesforce/apex/NKS_FedrekvotesakenController.hasExistingNavTasks';

const textMapping = {
    name: 'Barn mangler navn',
    birthday: 'Ugyldig fødselsdato for barn',
    leave: 'Du må svare på om du hadde permisjon',
    salary: 'Du må svare på om du fikk dekket lønn',
    fromDate: 'Ugyldig fra dato',
    toDate: 'Ugyldig til dato'
};

export default class NksFedrekvotesaken extends LightningElement {
    childCount = 1;
    plusCircle = `${PlusCircle}#PlusCircle`;
    errorList;

    loading = true;
    hasNavTask = false;

    connectedCallback() {
        hasExistingNavTasks()
            .then((res) => {
                this.hasNavTask = res;
            })
            .finally(() => {
                this.loading = false;
            });
    }

    addChild() {
        this.childCount++;
    }

    get childList() {
        return Array.from(new Array(this.childCount), (x, i) => i);
    }

    validateInputs() {
        const childValues = [];
        const allChildren = this.template.querySelectorAll('.children');
        let childErrors = [];
        allChildren.forEach((child) => {
            const childValue = child.getAndValidateChild();
            if (childValue.invalid.length > 0) {
                childErrors.push({ child, invalid: childValue.invalid });
            }
            childValues.push(childValue.data);
        });
        const phoneNumber = this.template.querySelector('c-ds-text-field')?.getValue();

        if (childErrors.length > 0 || phoneNumber === '' || phoneNumber == null) {
            this.showErrors(childErrors, phoneNumber);
            console.log('Wtf man');
            return;
        }
        let fedrekvoteData = {
            children: childValues,
            phone: phoneNumber
        };
        this.loading = true;
        createNavTask({ jsonData: JSON.stringify(fedrekvoteData) })
            .then(() => {
                this.hasNavTask = true;
            })
            .catch((e) => {
                console.log('Logging');
                LoggerUtility.logError(
                    'NKS',
                    'Fedrekvote',
                    e,
                    'Failed inserting NAV Task for fedrekvote, user input: ' + JSON.stringify(fedrekvoteData),
                    null
                );
            })
            .finally((this.loading = false));
    }

    showErrors(childErrors, phoneNumber) {
        this.errorList = { title: 'Du må fikse disse feilene før du kan sende inn meldingen.', errors: [] };
        for (const child of childErrors) {
            const childId = child.child.dataset.id;
            for (const invalid of child.invalid) {
                this.errorList.errors.push({
                    Id: this.errorList.length + 1,
                    EventItem: childId + '.' + invalid,
                    Text: textMapping[invalid]
                });
            }
        }
        if (phoneNumber === '' || phoneNumber == null) {
            this.errorList.errors.push({
                Id: this.errorList.length + 1,
                EventItem: '.phoneNumber',
                Text: 'Telefonnummer kan ikke være tom'
            });
        }
        let errorSummary = this.template.querySelector('.errorSummary');
        errorSummary.focusHeader();
    }

    handleErrorClick(e) {
        const detailSplit = e.detail.split('.');
        console.log(detailSplit);
        if (detailSplit[0] !== '') {
            const relevantChild = detailSplit[0];
            const relatedField = detailSplit[1];
            const childElement = this.template.querySelector(`c-nks-fedrekvotesaken-child[data-id="${relevantChild}"]`);
            childElement.focusElement(relatedField);
            return;
        }
        this.template.querySelector(detailSplit[1])?.focus();
    }
}

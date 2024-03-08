import { LightningElement } from 'lwc';
import PlusCircle from '@salesforce/resourceUrl/PlusCircle';
import LoggerUtility from 'c/loggerUtility';
import createNavTask from '@salesforce/apex/NKS_FedrekvotesakenController.createNavTask';
import hasExistingNavTasks from '@salesforce/apex/NKS_FedrekvotesakenController.hasExistingNavTasks';

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
        let allChildrenValid = true;
        allChildren.forEach((child) => {
            const childValue = child.getAndValidateChild();
            if (!childValue.valid) {
                allChildrenValid = false;
                return;
            }
            childValues.push(childValue.data);
        });
        const phoneNumber = this.template.querySelector('c-ds-text-field')?.getValue();

        if (!allChildrenValid || phoneNumber === '' || phoneNumber == null) {
            console.log('Wtf man');
            console.log(!allChildrenValid);
            console.log(phoneNumber === '');
            console.log(phoneNumber == null);
            return;
        }
        let fedrekvoteData = {
            children: childValues,
            phone: phoneNumber
        };
        createNavTask({ jsonData: JSON.stringify(fedrekvoteData) })
            .then(() => {
                this.hasNavTask = true;
            })
            .catch((e) => {
                LogerUtility.logError(
                    'NKS',
                    'Fedrekvote',
                    e,
                    'Failed inserting NAV Task for fedrekvote, user input: ' + JSON.stringify(fedrekvoteData),
                    null
                );
            });
    }
}

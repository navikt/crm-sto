import { LightningElement } from 'lwc';
import PlusCircle from '@salesforce/resourceUrl/PlusCircle';
import createNavTask from '@salesforce/apex/NKS_FedrekvotesakenController.createNavTask';
import hasExistingNavTasks from '@salesforce/apex/NKS_FedrekvotesakenController.hasExistingNavTasks';

export default class NksFedrekvotesaken extends LightningElement {
    childCount = 1;
    plusCircle = `${PlusCircle}#PlusCircle`;
    errorList;

    hasNoNavTask = false;

    connectedCallback() {
        hasExistingNavTasks().then((res) => {
            this.hasNoNavTask = res;
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
            children: allChildrenValid,
            phone: phoneNumber
        };
        createNavTask({ jsonData: JSON.stringify(fedrekvoteData) });
    }
}

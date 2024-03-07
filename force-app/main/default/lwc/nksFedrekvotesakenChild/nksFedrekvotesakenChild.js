import { LightningElement, api } from 'lwc';

export default class NksFedrekvotesakenChild extends LightningElement {
    leaveOptions = [
        { text: 'Ja', value: 'yes', checked: false },
        { text: 'Delvis', value: 'partly', checked: false },
        { text: 'Nei', value: 'no', checked: false }
    ];

    chosenOption;

    yesOptions = [
        { text: 'Ja', value: true, checked: false },
        { text: 'Nei', value: false, checked: false }
    ];

    radioChange(event) {
        this.chosenOption = event.detail;
    }

    get showSalary() {
        return this.chosenOption === 'yes' || this.chosenOption === 'partly';
    }
    get showDateRange() {
        return this.chosenOption === 'partly';
    }
    get showNo() {
        return this.chosenOption === 'no';
    }

    @api
    getAndValidateChild() {
        const name = this.template.querySelector('.nameField')?.getValue();
        const birthday = this.template.querySelector('.birthdayField')?.getValue();
        const radio = this.template.querySelector('.leaveRadio')?.getValue();
        const salary = this.template.querySelector('.salaryRadio')?.getValue();
        const fromDate = this.template.querySelector('.fromField')?.getValue();
        const toDate = this.template.querySelector('.toField')?.getValue();
        let validRadio =
            radio != null &&
            (radio === 'no' ||
                (radio === 'yes' && salary != null) ||
                (radio === 'partly' && fromDate != null && toDate != null));
        const valid = name != null && birthday != null && validRadio;
        let childData = {
            name: name,
            birthdate: birthday,
            leave: {
                type: radio,
                salary: salary,
                dates: {
                    fromDate: fromDate,
                    toDate: toDate
                }
            }
        };
        const nic = { valid, data: childData };
        return nic;
    }
}

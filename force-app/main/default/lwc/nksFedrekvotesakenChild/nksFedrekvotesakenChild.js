import { LightningElement, api } from 'lwc';

const elementMapping = {
    name: '.nameField',
    birthday: '.birthdayField',
    leave: '.leaveRadio',
    salary: '.salaryRadio',
    fromDate: '.toField',
    toDate: '.fromField'
};

export default class NksFedrekvotesakenChild extends LightningElement {
    leaveOptions = [
        { text: 'Ja', value: 'yes', checked: false },
        { text: 'Delvis', value: 'partly', checked: false },
        { text: 'Nei', value: 'no', checked: false }
    ];

    chosenOption;

    yesOptions = [
        { text: 'Ja', value: 'yes', checked: false },
        { text: 'Nei', value: 'no', checked: false }
    ];

    radioChange(event) {
        this.chosenOption = event.detail;
    }

    @api
    focusElement(element) {
        const elementClass = elementMapping[element];
        this.template.querySelector(elementClass)?.focus();
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
        const leave = this.template.querySelector('.leaveRadio')?.getValue();
        const salary = this.template.querySelector('.salaryRadio')?.getValue();
        const toDate = this.template.querySelector('.toField')?.getValue();
        const fromDate = this.template.querySelector('.fromField')?.getValue();
        let invalid = [];
        if (name == null || name === '') invalid.push('name');
        if (birthday == null) invalid.push('birthday');
        if (leave == null || leave === '') invalid.push('leave');
        if ((leave === 'yes' || leave === 'partly') && (salary == null || salary === '')) invalid.push('salary');
        if (leave === 'partly' && fromDate == null) invalid.push('fromDate');
        if (leave === 'partly' && toDate == null) invalid.push('toDate');
        let childData = {
            name: name,
            birthdate: birthday?.toLocaleDateString('no-nb', { day: 'numeric', month: 'long', year: 'numeric' }),
            leave: {
                type: leave,
                salary: salary,
                dates: {
                    fromDate: fromDate?.toLocaleDateString('no-nb', { day: 'numeric', month: 'long', year: 'numeric' }),
                    toDate: toDate?.toLocaleDateString('no-nb', { day: 'numeric', month: 'long', year: 'numeric' })
                }
            }
        };
        return { invalid, data: childData };
    }
}

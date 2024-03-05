import { LightningElement } from 'lwc';

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

    gege(event) {
        this.chosenOption = event.detail;
    }

    get showYes() {
        return this.chosenOption === 'yes';
    }
    get showMby() {
        return this.chosenOption === 'partly';
    }
    get showNo() {
        return this.chosenOption === 'no';
    }
}

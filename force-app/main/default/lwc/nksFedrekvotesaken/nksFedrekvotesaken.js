import { LightningElement } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';

export default class NksFedrekvotesaken extends LightningElement {
    logopath = navlogos + '/email.svg';

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

    geirArne() {
        console.log('Fimsk');
    }

    addChild() {
        console.log('Adding da baby');
    }

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

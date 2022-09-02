import { LightningElement, api } from 'lwc';

export default class DsRadio extends LightningElement {
    @api title;
    @api options; // List of label value objects

    connectedCallback() {
        this.options = this.options.map((option, index) => ({ ...option, id: 'radio-navds-id-' + index }));
    }

    @api
    getValue() {
        return this.template.querySelector('input[type=radio][name=radioGroupName-navds]:checked').value;
    }
}

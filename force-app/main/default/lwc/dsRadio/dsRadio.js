import { LightningElement, api } from 'lwc';

export default class DsRadio extends LightningElement {
    @api title;
    @api options; // List of label value objects
    showErrorText = false;
    UUID;

    connectedCallback() {
        this.UUID = crypto.randomUUID();
        this._options = this.options.map((option, index) => ({ ...option, id: 'radio-navds-id-' + index }));
    }

    getSelectedButton() {
        return this.template.querySelector(`input[type=radio][name=radioGroupName-navds-${this.UUID}]:checked`);
    }

    @api
    getValue() {
        return this.getSelectedButton()?.value;
    }

    @api
    focus() {
        const test = this.template.querySelectorAll('.navds-radio__input')[0];
        test?.focus();
    }

    checkForError() {
        this.updateErrorText();
    }

    handleChange() {
        const dataId = this.getSelectedButton().getAttribute('data-id');
        this._options.forEach((option) => (option.checked = option.id === dataId));
        this.updateErrorText();
        const changeEvent = new CustomEvent('radiochange', {
            detail: this.getValue()
        });
        this.dispatchEvent(changeEvent);
    }

    updateErrorText() {
        this.showErrorText = this.getValue() == null;
    }

    get radioName() {
        return 'radioGroupName-navds-' + this.UUID;
    }
}

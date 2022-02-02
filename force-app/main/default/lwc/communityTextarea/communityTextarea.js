import { LightningElement, api, track } from 'lwc';

export default class CommunityTextarea extends LightningElement {
    @api maxLength;
    errorMessage = 'Tekstfeltet kan ikke være tomt';
    message;
    errorState = false;

    publishMessage(event) {
        this.message = event.target.value;
        const textChangedEvent = new CustomEvent('textchanged', {
            detail: this.message
        });
        this.dispatchEvent(textChangedEvent);
    }

    handleMessage(event) {
        this.errorState = false;
        let text = event.target.value;
        this.message = text;
        let counter = this.template.querySelector('.remainingCounter');
        counter.ariaLive = text.length / this.maxLength >= 0.95 ? 'polite' : 'off';
    }

    get remainingCharacters() {
        return this.message ? this.maxLength - this.message.length : this.maxLength;
    }

    checkError() {
        this.errorState = !this.message || this.message.length == 0;
    }

    get wrapperClass() {
        return 'navds-form-field navds-form-field--medium' + (this.errorState ? ' navds-textarea--error' : '');
    }

    @api
    focus() {
        let textbox = this.template.querySelector('.tekstboks');
        textbox.focus();
    }
}

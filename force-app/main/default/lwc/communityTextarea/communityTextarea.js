import { LightningElement, api, track } from 'lwc';

export default class CommunityTextarea extends LightningElement {
    @api maxLength;
    errorMessage = 'Tekstfeltet kan ikke være tomt';
    message;
    errorState = false;

    renderedCallback() {
        if (this.mirror.style.minHeight == '') {
            this.mirror.style.minHeight = this.tekstboks.offsetHeight + 'px';
        }
    }

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
        this.mirror.textContent = this.message + '\n s';
        this.tekstboks.style.height = this.mirror.offsetHeight + 'px';
        let counter = this.template.querySelector('.remainingCounter');
        counter.ariaLive = this.remainingCharacters <= 20 ? 'polite' : 'off';
    }

    get remainingCharacters() {
        return this.message ? this.maxLength - this.message.length : this.maxLength;
    }

    get remainingCharacterText() {
        return (
            'Du har ' +
            Math.abs(this.remainingCharacters) +
            ' tegn ' +
            (this.remainingCharacters < 0 ? 'for mye' : 'igjen')
        );
    }

    get remainingCharacterClass() {
        return (
            'navds-textarea__counter navds-body-short remainingCounter' +
            (this.remainingCharacters < 0 ? ' navds-textarea__counter--error' : '')
        );
    }

    get tekstboks() {
        return this.template.querySelector('.tekstboks');
    }

    get mirror() {
        return this.template.querySelector('.mirror');
    }

    checkError() {
        this.errorState = !this.message || this.message.length == 0;
    }

    get wrapperClass() {
        return 'navds-form-field navds-form-field--medium' + (this.errorState ? ' navds-textarea--error' : '');
    }

    @api
    focus() {
        this.tekstboks.focus();
    }
}

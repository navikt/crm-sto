import { LightningElement, api } from 'lwc';

export default class StoThemeItem extends LightningElement {
    static delegatesFocus = true;
    @api theme;
    handleclick() {
        console.log('Clicked');
        const cEvent = new CustomEvent('themeselected', { detail: this.theme });
        this.dispatchEvent(cEvent);
    }
    handlekeyboard(event) {
        console.log('event.which');
    }
}
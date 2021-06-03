import { LightningElement, api } from 'lwc';

export default class StoThemeItem extends LightningElement {
    @api theme;
    handleclick() {
        const cEvent = new CustomEvent('themeselected', { detail: this.theme });
        this.dispatchEvent(cEvent);
    }
}
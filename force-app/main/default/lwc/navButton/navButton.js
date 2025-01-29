import { LightningElement, api } from 'lwc';
export default class NavButton extends LightningElement {
    @api title;
    @api url;
    @api logAmplitudeEvent = false;

    handleClick() {
        if (this.logAmplitudeEvent) {
            this.dispatchEvent(new CustomEvent('buttonclick'));
        }
    }
}

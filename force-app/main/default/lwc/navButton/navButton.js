import { LightningElement, api } from 'lwc';
export default class NavButton extends LightningElement {
    @api title;
    @api url;
    @api logAmplitudeEvent = false;

    handleClick() {
        if (this.logAmplitudeEvent) {
            this.dispatchEvent(new CustomEvent('logevent'));
        }
    }

    handleKeyDown(event) {
        if (event.key === ' ') event.preventDefault();
    }

    handleKeyUp(event) {
        if (event.key !== ' ') return;
        event.preventDefault();
        event.currentTarget.click();
    }
}

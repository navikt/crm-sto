import { LightningElement, api } from 'lwc';
import { logNavigationEvent } from 'c/stoUtils';
export default class NavButton extends LightningElement {
    @api title;
    @api url;

    handleClick() {
        logNavigationEvent({ url: this.url });
    }
}

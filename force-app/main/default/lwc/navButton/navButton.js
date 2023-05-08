import { LightningElement, api } from 'lwc';
export default class NavButton extends LightningElement {
    @api title;
    @api url;

    gotourl() {
        console.log(this.url);
        window.location.href = this.url + '&output=embed';
    }
}

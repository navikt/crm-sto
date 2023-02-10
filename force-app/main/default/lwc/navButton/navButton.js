import { LightningElement, api } from 'lwc';
import navStyling from '@salesforce/resourceUrl/navStyling';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class NavButton extends LightningElement {
    @api title;
    @api url;

    renderedCallback() {
        loadStyle(this, navStyling);
    }

    gotourl() {
        console.log(this.url);
        window.location.href = this.url + '&output=embed';
    }
}

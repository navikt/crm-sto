import { LightningElement, api } from 'lwc';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import { loadStyle } from 'lightning/platformResourceLoader';

export default class NavButton extends LightningElement {
    @api title; 
    @api url; 

    renderedCallback() {
        loadStyle(this, dekoratoren);
    }


    gotourl() {
        console.log(this.url); 
        window.location.href = (this.url+ "&output=embed"); 
    }

}
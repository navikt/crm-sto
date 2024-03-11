import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';

// import fonter from '@salesforce/resourceUrl/fonter';
import mbyFix from '@salesforce/resourceUrl/mbyFix';

export default class MortenFont extends LightningElement {
    connectedCallback() {
        loadStyle(this, mbyFix);
    }
}

import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';

import fonter from '@salesforce/resourceUrl/fonter';

export default class MortenFont extends LightningElement {
    connectedCallback() {
        loadStyle(this, fonter);
    }
}

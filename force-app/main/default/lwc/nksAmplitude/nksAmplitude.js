import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import Amplitude from '@salesforce/resourceUrl/Amplitude';

export default class NksAmplitude extends LightningElement {
    static renderMode = 'light';

    connectedCallback() {
        loadScript(this, Amplitude + '/Amplitude.js').then(() => {
            window.amplitude.init('0daf26baf4c01a4d9eda01d53669d001', '', {
                apiEndpoint: 'amplitude.nav.no/collect',
                serverZone: 'EU',
                saveEvents: false,
                includeUtm: true,
                batchEvents: false,
                includeReferrer: true
            });
        });
    }
}

import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import Amplitude from '@salesforce/resourceUrl/Amplitude';

export default class NksAmplitude extends LightningElement {
    static renderMode = 'light';

    connectedCallback() {
        loadScript(this, Amplitude + '/Amplitude.js').then(() => {
            window.amplitude.init('API-KEY', '', {
                apiEndpoint: 'amplitude.nav.no/collect-auto',
                saveEvents: false,
                includeUtm: true,
                includeReferrer: true,
                platform: window.location.toString()
            });
        });
    }
}

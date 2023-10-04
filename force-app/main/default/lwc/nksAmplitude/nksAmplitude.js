import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import Amplitude from '@salesforce/resourceUrl/Amplitude';
import { handleClickableElements } from 'c/nksAmplitudeUtils';
import getUserDepartment from '@salesforce/apex/NKS_AmplitudeHelper.getUserDepartment';
export default class NksAmplitude extends LightningElement {
    static renderMode = 'light';
    @track department;

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

        getUserDepartment().then((result) => {
            this.department = result;
            handleClickableElements(this.department);
        });
    }
}

import { LightningElement } from 'lwc';
import { logAmplitudeEvent } from 'c/nksAmplitudeUtils';
import getUserDepartment from '@salesforce/apex/NKS_AmplitudeHelper.getUserDepartment';

export default class TestLinksCmp extends LightningElement {
    url = 'https://nav.no/skriv-til-oss';
    department;

    connectedCallback() {
        getUserDepartment().then((result) => {
            this.department = result;
        });
    }

    handleClick() {
        window.open(this.url);
        logAmplitudeEvent('Test Event', {
            type: 'Navigate to STO',
            department: this.department
        });
    }
}

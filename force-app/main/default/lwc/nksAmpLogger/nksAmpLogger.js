import { LightningElement } from 'lwc';

export default class NksAmpLogger extends LightningElement {
    handleClick(event) {
        const a = window.amplitude;
        a.track('Morten har en good time');
    }
}

import { LightningElement } from 'lwc';

export default class NksAmpLogger extends LightningElement {
    handleClick(event) {
        const a = window.amplitude;
        console.log('click');
        console.log(event);
        console.log(JSON.stringify(event));
        console.log(JSON.stringify(a));
        console.log(JSON.stringify(amplitude));
        console.log(JSON.stringify(event.srcElement));
        (event.srcElement.parentElement) ? console.log(event.srcElement.parentElement):console.log('no parent');
        let properties = {
            'type' : event.type,
            'srcElement': event.srcElement.localName,
            'host': window.document.location.hostname,
            'path': window.document.location.pathname
        };
        console.log(JSON.stringify(properties));
        a.track('Hello World!',properties);
    }
}

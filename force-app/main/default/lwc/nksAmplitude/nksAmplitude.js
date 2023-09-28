import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import Amplitude from '@salesforce/resourceUrl/Amplitude';

export default class NksAmplitude extends LightningElement {
    static renderMode = 'light';

    disconnectedCallback() {
        this.unsubscribeToClicks();
    }

    connectedCallback() {
        this.subscribeToClicks();
        loadScript(this, Amplitude + '/Amplitude.js').then(() => {
            window.amplitude.init('0daf26baf4c01a4d9eda01d53669d001', '', {
                apiEndpoint: 'amplitude.nav.no/collect',
                serverZone: 'EU',
                saveEvents: false,
                includeUtm: true,
                batchEvents: false,
                includeReferrer: true
            });
            console.log('Amplitude loaded!');
        });
    }

    clickTime;
    clickHandler(event) {
        this.clickTime = new Date().getTime();
        //console.log('HTML class clicked: ', event.target.classList);
        //console.log('Event target data aura class: ', event.target.getAttribute('data-aura-class'));
        //window.amplitude.track('Mouse click', event.target);

        let currentElement = event.target;
        console.log('currentelement: ', currentElement);

        // Get last child node in tree based on element
        let bottomEle = this.findDeepestChild(currentElement);
        console.log('bottomElement from traverse: ', bottomEle);

        // Get element based on coordinates
        const x = event.clientX;
        const y = event.clientY;
        const clickedElement = document.elementFromPoint(x, y);
        console.log(x, y);
        console.log('clickedElement from coordinates: ', clickedElement);
    }

    findDeepestChild(element) {
        if (element.children.length === 0) {
            return element;
        }
        let deepestElement = element;
        Array.from(element.children).forEach((child) => {
            const deepestChild = findDeepestChild(child);

            if (deepestChild && deepestChild !== child) {
                deepestElement = deepestChild;
            }
        });
        return deepestElement;
    }

    subscribeToClicks() {
        document.addEventListener(
            'mousedown',
            (event) => {
                setTimeout(() => {
                    this.clickHandler(event);
                }, 5000); // Set 5 sec timeout to allow page to rerender fully before listening to event
            },
            true
        );
    }

    unsubscribeToClicks() {
        document.removeEventListener('mousedown', this.clickHandler);
    }
}

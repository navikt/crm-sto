import { LightningElement } from 'lwc';

export default class NksFedrekvotesaken extends LightningElement {
    childCount = 1;

    geirArne() {
        console.log('Fimsk');
    }

    addChild() {
        this.childCount++;
    }

    get childList() {
        return Array.from(new Array(this.childCount), (x, i) => i);
    }
}

import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class BtoViewThread extends LightningElement {
    threadId;
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.threadId = currentPageReference.state.samtale;
        }
    }
}

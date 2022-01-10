import { LightningElement, api } from 'lwc';

export default class CommunityErrorSummary extends LightningElement {
    @api errorList;
    @api showWarnings;
    bufferFocus = false;

    @api focusHeader() {
        if (this.showWarnings) {
            let heading = this.template.querySelector('.navds-error-summary__heading');
            heading.focus();
        } else {
            this.bufferFocus = true;
        }
    }

    renderedCallback() {
        if (this.bufferFocus) {
            let heading = this.template.querySelector('.navds-error-summary__heading');
            heading.focus();
            this.bufferFocus = false;
        }
    }

    test(event) {
        event.preventDefault();
        let item = event.target.getAttribute('event-item');
        const clickedEvent = new CustomEvent('clickedevent', {
            detail: item
        });

        this.dispatchEvent(clickedEvent);
    }
}

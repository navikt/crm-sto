import { LightningElement, api } from 'lwc';

export default class NksReadMore extends LightningElement {
    @api title;

    isExpanded = false;

    toggleExpand() {
        console.log('toggleExpand called');
        this.isExpanded = !this.isExpanded;
        console.log('isExpanded:', this.isExpanded);
    }

    get readMoreStateClass() {
        return 'navds-read-more navds-read-more--medium ' + (this.isExpanded ? 'navds-read-more--open' : '');
    }

    get readMoreContentStateClass() {
        return (
            'navds-read-more__content navds-body-long navds-body-long--medium slds-text-align_left ' +
            (!this.isExpanded ? 'navds-read-more__content--closed' : '')
        );
    }

    get ariaHidden() {
        return this.isExpanded ? 'false' : 'true';
    }

    get dataState() {
        return this.isExpanded ? 'closed' : 'open';
    }
}

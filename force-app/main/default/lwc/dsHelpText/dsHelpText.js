import { LightningElement, api } from 'lwc';

export default class DsHelpText extends LightningElement {
    @api title = 'Mangler tittel';
    @api text = 'Mangler tekst';
    open = false;

    test() {
        this.open = !this.open;
    }

    test2(event) {
        const div = this.template.querySelector('.tester1');
        this.open = event.relatedTarget !== null && div.contains(event.relatedTarget);
    }

    get popoverClasses() {
        return (
            'navds-popover navds-help-text__popover overrideableClasses popoverTop popoverRight--mobile popoverPosition' +
            (this.open === true ? '' : ' navds-popover--hidden')
        );
    }
}

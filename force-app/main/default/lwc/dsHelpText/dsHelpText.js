import { LightningElement, api } from 'lwc';

export default class DsHelpText extends LightningElement {
    @api title = 'Mangler tittel';
    @api text = 'Mangler tekst';
    open = false;

    clickHelpText() {
        this.open = !this.open;
    }

    keyboardHandler(event) {
        if (event.key === 'Escape') {
            this.open = false;
        }
    }

    focusClose(event) {
        const div = this.template.querySelector('.tester1');
        if (event.relatedTarget === null || !div.contains(event.relatedTarget)) this.open = false;
    }

    get popoverClasses() {
        return (
            'navds-popover navds-help-text__popover overrideableClasses popoverTop popoverRight--mobile popoverPosition' +
            (this.open === true ? '' : ' navds-popover--hidden')
        );
    }
}

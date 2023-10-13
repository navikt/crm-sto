import { LightningElement, api } from 'lwc';
import { trackAmplitudeEvent } from 'c/amplitude';
export default class NksFlowButton extends LightningElement {
    @api flowName;
    @api buttonLabel;
    @api buttonColor;
    @api inputVariables;
    @api isDisabled = false;

    showFlow = false;

    get ariaExpanded() {
        return this.showFlow.toString();
    }

    get buttonClassName() {
        let color = this.buttonColor?.toLowerCase();
        switch (color) {
            case 'blue':
                return 'button blue';

            case 'green':
                return 'button green';

            default:
                return 'button';
        }
    }

    toggleFlow() {
        trackAmplitudeEvent('STO' + this.buttonLabel + 'pressed');
        this.showFlow = !this.showFlow;
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
        this.dispatchEvent(new CustomEvent('flowfinished'));
    }
}

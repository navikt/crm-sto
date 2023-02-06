import { LightningElement, api } from 'lwc';

export default class NksFlowButton extends LightningElement {
    @api flowName;
    @api buttonLabel;
    @api buttonColor;
    @api inputVariables;
    @api isDisabled = false;
    @api refreshRecord;

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
        this.showFlow = !this.showFlow;
    }

    handleStatusChange(event) {
        let flowStatus = event.detail.status;
        if (flowStatus === 'FINISHED' || flowStatus === 'FINISHED_SCREEN') {
            this.showFlow = false;
        }
        this.refreshRecord();
    }
}

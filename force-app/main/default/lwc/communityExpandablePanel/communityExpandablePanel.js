import { LightningElement, api } from 'lwc';
import { logAccordionEvent, getComponentName } from 'c/inboxAmplitude';

export default class CommunityExpandablePanel extends LightningElement {
    @api title;
    @api simple = false;

    isExpanded = false;

    toggleExpand() {
        this.isExpanded = !this.isExpanded;
        logAccordionEvent(this.showpanel, this.header, getComponentName(this.template));
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.toggleExpand();
        }
    }

    get containerStyle() {
        return this.simple ? 'panel-background' : 'panel-background panel-background-bottom-border';
    }

    get panelHeaderClass() {
        return (
            'panel-header-expandable ' +
            (this.simple ? 'panel-header-simple' : 'panel-header panel-header-padding-small')
        );
    }

    get chevronClass() {
        return (
            'slds-icon slds-icon-text-default slds-icon_small custom-chevron' +
            (this.isExpanded ? ' rotate-chevron' : '')
        );
    }

    get chevronIconClass() {
        return this.simple ? 'custom-icon-chevron-simple' : 'custom-icon-chevron';
    }

    get panelBodyClass() {
        return (
            'panel-body ' +
            (this.simple ? 'panel-body-left-simple panel-body-x_small' : 'panel-body-left panel-body-small')
        );
    }
}

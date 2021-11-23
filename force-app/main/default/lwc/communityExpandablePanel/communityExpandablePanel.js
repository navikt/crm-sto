import { LightningElement, api } from 'lwc';

export default class CommunityExpandablePanel extends LightningElement {
    showpanel = false;
    @api header;
    @api body;

    togglevisible() {
        this.showpanel = !this.showpanel;
        this.performAnimation();
    }

    get chevronClass() {
        return (
            'nav-frontend-chevron slds-float_right ' +
            (this.showpanel ? 'chevron--opp' : 'chevron--ned') +
            ' chevronboks'
        );
    }

    // To perform animations we can't use height:auto, so we use auto to get the height
    // and set the height to that value.
    performAnimation() {
        let wrapper = this.template.querySelector('.dropdown');
        if (wrapper) {
            let content = wrapper.children[0];
            if (this.showpanel) {
                content.style.height = 'auto';
                let boundingRect = content.getBoundingClientRect();
                content.style.height = '0px';
                window.requestAnimationFrame(function () {
                    content.style.height = boundingRect.height + 'px';
                });
            } else {
                content.style.height = '0px';
            }
        }
    }
}

import { LightningElement, api } from 'lwc';

export default class CommunityExpandablePanel extends LightningElement {
    showpanel = false;
    @api header;
    @api body;

    togglevisible() {
        this.showpanel = !this.showpanel;
        this.performAnimation();
    }

    get accordianClass() {
        return 'navds-accordion__item ' + (this.showpanel ? 'navds-accordion__item--open' : '');
    }

    get inverseShowpanel() {
        return !this.showpanel;
    }

    // To perform animations we can't use height:auto, so we use auto to get the height
    // and set the height to that value.
    performAnimation() {
        let expand = this.template.querySelector('.expand-animation');
        let wrapper = this.template.querySelector('.dropdown');
        if (wrapper && expand) {
            if (this.showpanel) {
                wrapper.style.display = null;
                expand.style.height = 'auto';
                let boundingRect = expand.getBoundingClientRect();
                expand.style.height = '0px';
                window.requestAnimationFrame(function () {
                    expand.style.height = boundingRect.height + 'px';
                });
                setTimeout(() => {
                    if (this.showpanel) {
                        expand.style.height = 'auto';
                    }
                }, 250);
            } else {
                let boundingRect = expand.getBoundingClientRect();
                expand.style.height = boundingRect.height + 'px';
                window.requestAnimationFrame(function () {
                    expand.style.height = '0px';
                });
                setTimeout(() => {
                    wrapper.display = 'none';
                }, 250);
            }
        }
    }
}

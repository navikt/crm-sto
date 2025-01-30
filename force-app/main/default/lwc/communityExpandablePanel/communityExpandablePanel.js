import { LightningElement, api } from 'lwc';
import { logAccordionEvent } from 'c/amplitude';

export default class CommunityExpandablePanel extends LightningElement {
    @api header;
    @api body;
    @api pageType;

    showpanel = false;

    togglevisible() {
        this.showpanel = !this.showpanel;
        this.performAnimation();
        logAccordionEvent(this.showPanel, this.header, this.pageType, 'communityExpandablePanel');
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
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.requestAnimationFrame(function () {
                    expand.style.height = boundingRect.height + 'px';
                });
                // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
                setTimeout(() => {
                    if (this.showpanel) {
                        expand.style.height = 'auto';
                    }
                }, 250);
            } else {
                let boundingRect = expand.getBoundingClientRect();
                expand.style.height = boundingRect.height + 'px';
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.requestAnimationFrame(function () {
                    expand.style.height = '0px';
                });
                // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
                setTimeout(() => {
                    wrapper.display = 'none';
                }, 250);
            }
        }
    }
}

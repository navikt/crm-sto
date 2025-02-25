import { LightningElement, api } from 'lwc';
import navlogos from '@salesforce/resourceUrl/homelogo';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/index';
import { loadStyle } from 'lightning/platformResourceLoader';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';

export default class CommunityBreadCrumb extends LightningElement {
    @api firstLevel;
    @api firstLevelLink;
    @api secondLevel;
    @api secondLevelLink;
    @api thirdLevel;
    @api thirdLevelLink;
    @api leafnode;

    homelogo = navlogos;

    renderedCallback() {
        loadStyle(this, index);
        loadStyle(this, navStyling);
    }

    handleClick(event) {
        logNavigationEvent(
            getComponentName(this.template),
            'breadCrumb',
            event.currentTarget.href,
            event.currentTarget.textContent.trim()
        );
    }
}

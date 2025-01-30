import { LightningElement, api } from 'lwc';
import navlogos from '@salesforce/resourceUrl/homelogo';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/index';
import { loadStyle } from 'lightning/platformResourceLoader';
import { logNavigationEvent } from 'c/amplitude';

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
            'communityBreadCrumb',
            'breadCrumb',
            event.currentTarget.href,
            event.currentTarget.textContent.trim()
        );
    }
}

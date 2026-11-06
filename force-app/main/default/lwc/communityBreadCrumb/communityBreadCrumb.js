import { LightningElement, api } from 'lwc';
import navlogos from '@salesforce/resourceUrl/homelogo';
import navStyling from '@salesforce/resourceUrl/navStyling';
import index from '@salesforce/resourceUrl/newIndex';
import { loadStyle } from 'lightning/platformResourceLoader';
import { logNavigationEvent, getComponentName } from 'c/inboxAmplitude';
import { resolveNavUrls } from 'c/navUrl';

export default class CommunityBreadCrumb extends LightningElement {
    @api firstLevel;
    @api firstLevelLink;
    @api secondLevel;
    @api secondLevelLink;
    @api thirdLevel;
    @api thirdLevelLink;
    @api leafnode;

    homelogo = navlogos;
    homeUrl = resolveNavUrls('https://www.nav.no');

    get resolvedFirstLevelLink() {
        return resolveNavUrls(this.firstLevelLink);
    }

    get resolvedSecondLevelLink() {
        return resolveNavUrls(this.secondLevelLink);
    }

    get resolvedThirdLevelLink() {
        return resolveNavUrls(this.thirdLevelLink);
    }

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

import { LightningElement, api } from 'lwc';
import { updateBreadcrumbs } from 'c/inboxAmplitude';

export default class CommunityBreadCrumbV2 extends LightningElement {
    @api firstLevel;
    @api firstLevelLink;
    @api secondLevel;
    @api secondLevelLink;
    @api thirdLevel;
    @api thirdLevelLink;
    @api leafnode;

    renderedCallback() {
        updateBreadcrumbs([
            { url: this.firstLevelLink, title: this.firstLevel },
            { url: this.secondLevelLink, title: this.secondLevel },
            { url: this.thirdLevelLink, title: this.thirdLevel },
            { url: '', title: this.leafnode }
        ]);
    }
}

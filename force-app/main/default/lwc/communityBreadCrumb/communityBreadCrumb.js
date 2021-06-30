import { LightningElement, api } from 'lwc';
import navlogos from '@salesforce/resourceUrl/navsvglogos';

export default class CommunityBreadCrumb extends LightningElement {
    @api firstLevel;
    @api firstLevelLink;
    @api secondLevel
    @api secondLevelLink
    @api thirdLevel;
    @api thirdLevelLink;
    @api leafnode
    homelogo = navlogos + '/home.svg';

}
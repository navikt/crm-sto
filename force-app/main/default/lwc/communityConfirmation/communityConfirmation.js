import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import NAV_SVG_LOGOS from '@salesforce/resourceUrl/navsvglogos';

export default class CommunityConfirmation extends NavigationMixin(LightningElement) {
    @api title;
    @api text;

    submitRequest() {
        const config = {
            type: 'standard__webPage',
            attributes: {
                url: 'https://www.nav.no/minside'
            }
        };
        this[NavigationMixin.Navigate](config);
    }

    get applicationSuccessSrc() {
        return NAV_SVG_LOGOS + '/ApplicationSuccess.svg#ApplicationSuccess';
    }
}

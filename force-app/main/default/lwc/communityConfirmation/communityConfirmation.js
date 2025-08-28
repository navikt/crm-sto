import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

import NAV_SVG_LOGOS from '@salesforce/resourceUrl/navsvglogos';

export default class CommunityConfirmation extends NavigationMixin(LightningElement) {
    category;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.category = currentPageReference.state.category;
            console.log('Category received:', this.category);
        }
    }

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

    get title() {
        const messages = {
            beskjed: 'Vi har mottatt meldingen din. Takk for at du tok kontakt.',
            endring: 'Endringen er registrert. Takk for at du ga beskjed.',
            'trekke-soknad': 'Vi har mottatt beskjed om at du ønsker å trekke søknaden. Takk for at du informerte oss.'
        };

        return Object.entries(messages).find(([key]) => this.category?.includes(key))?.[1] || '';
    }

    get text() {
        return 'Vi kontakter deg hvis vi trenger mer informasjon';
    }
}

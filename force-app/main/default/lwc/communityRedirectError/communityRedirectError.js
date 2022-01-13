import { LightningElement } from 'lwc';

import { NavigationMixin } from 'lightning/navigation';

export default class CommunityRedirectError extends NavigationMixin(LightningElement) {
    connectedCallback() {
        this.handleNavigate('https://www.nav.no/error');
    }

    handleNavigate(url) {
        this[NavigationMixin.GenerateUrl](
            {
                type: 'standard__webPage',
                attributes: {
                    url: url,
                    target: '_self'
                }
            } // Replaces the current page in your browser history with the URL
        ).then((generatedUrl) => {
            window.open(generatedUrl, '_self');
        });
    }
}

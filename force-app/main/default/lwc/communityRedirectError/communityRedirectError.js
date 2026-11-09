import { LightningElement } from 'lwc';
import { resolveNavUrls } from 'c/navUrl';

import { NavigationMixin } from 'lightning/navigation';

export default class CommunityRedirectError extends NavigationMixin(LightningElement) {
    connectedCallback() {
        this.handleNavigate(resolveNavUrls('https://www.nav.no/error'));
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
            // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
            window.open(generatedUrl, '_self');
        });
    }
}

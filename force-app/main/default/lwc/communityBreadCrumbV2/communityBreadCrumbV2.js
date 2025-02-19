import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { updateBreadcrumbs } from 'c/inboxAmplitude';
import getThread from '@salesforce/apex/stoHelperClass.getThread';

export default class CommunityBreadCrumbV2 extends LightningElement {
    recordId;
    leafnode;
    breadcrumbs = [];

    typeMap = {
        Endring: 'Meld fra om endring',
        'Trekke-soknad': 'Trekke en søknad',
        Beskjed: 'Gi beskjed'
    };

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const state = currentPageReference?.state;
            const name = currentPageReference.attributes.name;
            const category = state?.category;
            const samtale = state?.samtale;

            if (name === 'Visning__c' && samtale) {
                this.recordId = samtale;
                if (this.recordId) {
                    this.fetchThread(this.recordId);
                } else {
                    console.warn('fetchThread not called: recordId is undefined or null');
                }
            } else if (name === 'Home') {
                this.breadcrumbs = [
                    { url: 'https://nav.no', title: 'Privatperson' },
                    { url: 'https://www.nav.no/minside/', title: 'Min side' },
                    { url: '', title: 'Innboks' }
                ];
                updateBreadcrumbs(this.breadcrumbs);
                console.log('breadcrumbs: ', JSON.stringify(this.breadcrumbs));
                return;
            } else if (category && ['Endring', 'Beskjed', 'Trekke-soknad'].some((item) => category.includes(item))) {
                Object.keys(this.typeMap).forEach((key) => {
                    if (category.includes(key)) {
                        this.leafnode = this.typeMap[key];
                    }
                });
            } else {
                this.leafnode = 'Skriv til oss';
            }
            this.updateBreadcrumbs();
        }
    }

    async fetchThread(recordId) {
        try {
            const data = await getThread({ recordId });
            if (data) {
                this.leafnode = data.NKS_Inbox_Type__c;
            } else {
                console.warn('No data returned from getThread');
            }
        } catch (error) {
            console.error('Problem getting thread:', error);
            this.leafnode = 'Beskjed til oss';
        }
        this.updateBreadcrumbs();
    }

    updateBreadcrumbs() {
        this.breadcrumbs = [
            { url: 'https://nav.no', title: 'Privatperson' },
            { url: 'https://www.nav.no/minside/', title: 'Min side' },
            { url: 'https://innboks.nav.no', title: 'Innboks' },
            { url: '', title: this.leafnode }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }
}

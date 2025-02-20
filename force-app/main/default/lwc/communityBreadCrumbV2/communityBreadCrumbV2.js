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
        if (!currentPageReference) return;
        const state = currentPageReference?.state;
        const name = currentPageReference?.attributes?.name;
        const category = state?.category;
        const samtale = state?.samtale;

        if (name === 'Visning__c' && samtale) {
            this.fetchThread(samtale);
        } else if (name === 'Home') {
            this.setHomeBreadcrumbs();
        } else {
            this.setCategoryBreadcrumbs(category);
        }
    }

    async fetchThread(recordId) {
        this.recordId = recordId;
        try {
            const data = await getThread({ recordId });
            this.leafnode = data?.NKS_Inbox_Title__c ?? 'Beskjed til oss';
        } catch (error) {
            console.error('Problem getting thread:', error);
            this.leafnode = 'Beskjed til oss';
        }
        this._updateBreadcrumbs();
    }

    setHomeBreadcrumbs() {
        this.breadcrumbs = [
            { url: 'https://nav.no', title: 'Privatperson' },
            { url: 'https://www.nav.no/minside/', title: 'Min side' },
            { url: '', title: 'Innboks' }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }

    setCategoryBreadcrumbs(category) {
        this.leafnode = Object.keys(this.typeMap).find((key) => category?.includes(key))
            ? this.typeMap[category]
            : 'Skriv til oss';
        this._updateBreadcrumbs();
    }

    _updateBreadcrumbs() {
        this.breadcrumbs = [
            { url: 'https://nav.no', title: 'Privatperson' },
            { url: 'https://www.nav.no/minside/', title: 'Min side' },
            { url: 'https://innboks.nav.no', title: 'Innboks' },
            { url: '', title: this.leafnode }
        ];
        updateBreadcrumbs(this.breadcrumbs);
    }
}

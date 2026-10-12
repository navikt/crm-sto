import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getThreads from '@salesforce/apex/stoInboxHelper.getThreads';
import getRecentThreads from '@salesforce/apex/stoInboxHelper.getRecentThreads';
import { logNavigationEvent, getComponentName, setDecoratorParams } from 'c/inboxAmplitude';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';

const SELF_PERSON_VALUE = 'self';
const MOCK_HAS_FORELDREANSVAR = true;

const MOCK_REPRESENTABLE_CHILDREN = [
    { label: 'Beate Normann (datter, 8 år)', value: 'mock-child-1' },
    { label: 'Ola Normann (sønn, 12 år)', value: 'mock-child-2' }
];

const MOCK_CHILD_THREADS = {
    'mock-child-1': {
        recent: [
            {
                recordId: 'mock-thread-1',
                category: 'Familie',
                name: 'Familie og barn - Skriv til oss: Du sendte en melding',
                latestMessageDate: '2026-10-10T09:15:00.000Z',
                latestmessage: { Message: 'Spørsmål om barnetrygd for Beate.' },
                status: 'Åpen',
                objectName: 'Thread__c'
            }
        ],
        older: [
            {
                recordId: 'mock-thread-2',
                category: 'Helse',
                name: 'Helse og sykdom - Skriv til oss: Du sendte en melding',
                latestMessageDate: '2026-06-02T13:40:00.000Z',
                latestmessage: { Message: 'Gjelder grunnstønad.' },
                status: 'Lukket',
                objectName: 'Thread__c'
            }
        ]
    },
    'mock-child-2': {
        recent: [],
        older: []
    }
};

const ALL_CATEGORIES_VALUE = 'all';

export default class StoMessageInbox extends LightningElement {
    @api title;

    threads;
    recentthreads;
    wthreads;
    wrthreads;
    showthreads = false;
    showrecentthreads = false;
    hasRefreshed = false;
    currentUserName = '';
    selectedPersonValue = SELF_PERSON_VALUE;
    selectedCategoryValues = new Set();

    renderedCallback() {
        setDecoratorParams('Innboks', 'Innboks', '');

        if (this.hasRefreshed) return;
        if (!this.wthreads || !this.wrthreads) return;

        this.hasRefreshed = true;
        refreshApex(this.wthreads);
        refreshApex(this.wrthreads);
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
    wiredCurrentUser({ data, error }) {
        if (data) {
            this.currentUserName = getFieldValue(data, USER_NAME_FIELD) || '';
        } else if (error) {
            this.currentUserName = '';
            console.error('Could not load current user name:', error);
        }
    }

    @wire(getThreads, {})
    wirethreads(result) {
        this.wthreads = result;
        if (result.error) {
            console.error(result.error);
        } else if (result.data) {
            this.setThreads();
        }
    }

    @wire(getRecentThreads, {})
    wirerecentthreads(result) {
        this.wrthreads = result;
        if (result.error) {
            console.error(result.error);
        } else if (result.data) {
            this.setRecentThreads();
        }
    }

    setThreads() {
        if (this.wthreads.data) {
            this.threads = this.wthreads.data.filter(Boolean).sort(this.sortByDate);
            this.showthreads = this.threads.length > 0;
        }
    }

    setRecentThreads() {
        if (this.wrthreads.data) {
            this.recentthreads = this.wrthreads.data.filter(Boolean).sort(this.sortByDate);
            this.showrecentthreads = this.recentthreads.length > 0;
        }
    }

    sortByDate(t1, t2) {
        const d1 = new Date(t1.latestMessageDate);
        const d2 = new Date(t2.latestMessageDate);
        if (d1 > d2) return -1;
        if (d1 < d2) return 1;
        return 0;
    }

    handleDocumentArchiveClick() {
        logNavigationEvent(
            getComponentName(this.template),
            'brev og vedtak',
            'https://www.nav.no/dokumentarkiv',
            'brev og vedtak'
        );
    }

    handleContactUsClick() {
        logNavigationEvent(
            getComponentName(this.template),
            'kontakt oss',
            'https://www.nav.no/kontaktoss',
            'Kontakt oss'
        );
    }

    handleCategoryChange(event) {
        const value = event.detail?.value;
        const valid = this.categoryOptions.some((option) => option.value === value);
        if (!valid) return;

        if (value === 'all') {
            this.selectedCategoryValues = new Set();
            return;
        }

        const next = new Set(this.selectedCategoryValues);
        if (next.has(value)) {
            next.delete(value);
        } else {
            next.add(value);
        }
        this.selectedCategoryValues = next;
    }

    handlePersonChange(event) {
        const value = event.detail?.value;
        const validOption = this.personOptions.some((option) => option.value === value);
        this.selectedPersonValue = validOption ? value : SELF_PERSON_VALUE;
        this.selectedCategoryValues = new Set();
    }

    get selfPersonLabel() {
        return this.currentUserName ? `Deg (${this.currentUserName})` : 'Deg';
    }

    get canRepresentChildren() {
        return MOCK_HAS_FORELDREANSVAR && MOCK_REPRESENTABLE_CHILDREN.length > 0;
    }

    get personOptions() {
        return [
            { label: this.selfPersonLabel, value: SELF_PERSON_VALUE },
            ...(this.canRepresentChildren ? MOCK_REPRESENTABLE_CHILDREN : [])
        ];
    }

    get chipOptions() {
        return this.categoryOptions.map((option) => ({
            ...option,
            selected:
                option.value === 'all' ? this.isAllCategoriesSelected : this.selectedCategoryValues.has(option.value)
        }));
    }

    get isSelfSelected() {
        return this.selectedPersonValue === SELF_PERSON_VALUE;
    }

    get mockChildThreads() {
        return MOCK_CHILD_THREADS[this.selectedPersonValue] || { recent: [], older: [] };
    }

    get isDataLoaded() {
        return Boolean(this.wthreads && this.wrthreads);
    }

    get noItems() {
        if (this.isSelfSelected && !this.isDataLoaded) {
            return false;
        }
        return !this.showVisibleRecentThreads && !this.showVisibleThreads;
    }

    get noItemsText() {
        return this.isSelfSelected
            ? 'Du har ingen meldinger i innboksen din.'
            : 'Det finnes ingen meldinger for denne personen.';
    }

    getThreadCategory(thread) {
        return thread?.category?.trim() || '';
    }

    get personRecentThreads() {
        const threads = this.isSelfSelected ? this.recentthreads || [] : this.mockChildThreads.recent;

        return threads.filter(Boolean).sort(this.sortByDate);
    }

    get personThreads() {
        const threads = this.isSelfSelected ? this.threads || [] : this.mockChildThreads.older;

        return threads.filter(Boolean).sort(this.sortByDate);
    }

    get totalPersonMessages() {
        return this.personRecentThreads.length + this.personThreads.length;
    }

    get categoryOptions() {
        if (this.totalPersonMessages === 0) {
            return [];
        }

        const categories = new Set(
            [...this.personRecentThreads, ...this.personThreads]
                .map((thread) => this.getThreadCategory(thread))
                .filter(Boolean)
        );

        return [
            { label: 'Vis alle', value: ALL_CATEGORIES_VALUE },
            ...[...categories]
                .sort((first, second) => first.localeCompare(second, 'nb'))
                .map((category) => ({ label: category, value: category }))
        ];
    }

    get showCategoryFilter() {
        return this.totalPersonMessages > 0;
    }

    filterThreads(threads) {
        if (this.isAllCategoriesSelected) {
            return threads;
        }

        return threads.filter((thread) => this.selectedCategoryValues.has(this.getThreadCategory(thread)));
    }

    get isAllCategoriesSelected() {
        return this.selectedCategoryValues.size === 0;
    }

    get visibleRecentThreads() {
        return this.filterThreads(this.personRecentThreads);
    }

    get visibleThreads() {
        return this.filterThreads(this.personThreads);
    }

    get showVisibleRecentThreads() {
        return this.visibleRecentThreads.length > 0;
    }

    get showVisibleThreads() {
        return this.visibleThreads.length > 0;
    }
}

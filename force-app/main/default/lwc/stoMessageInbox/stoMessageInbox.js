import { LightningElement, wire, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
// TODO(backend-ready): Preserve account-scoped inbox queries with the real authorization provider.
import getInboxPage from '@salesforce/apex/stoInboxHelper.getInboxPage';
import getNextInboxPage from '@salesforce/apex/stoInboxHelper.getNextInboxPage';
import getRepresentableChildren from '@salesforce/apex/stoPersonContext.getRepresentableChildren';
import { logNavigationEvent, getComponentName, setDecoratorParams } from 'c/inboxAmplitude';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import { READ_STATE_EVENT } from 'c/stoReadState';

const SELF_PERSON_VALUE = 'self';
// TODO(backend-ready): All children and their threads now come from Apex; do not restore client fixtures.
const ALL_CATEGORIES_VALUE = 'all';

export default class StoMessageInbox extends NavigationMixin(LightningElement) {
    @api title;

    threads;
    recentthreads;
    wiredInbox;
    refreshPending = true;
    refreshFailed = false;
    pageLoadFailed = false;
    loadingMore = false;
    hasMore = false;
    beforeThreadId;
    beforeNoteId;
    pageGeneration = 0;
    isOnInbox = true;
    currentUserName = '';
    selectedPersonValue = SELF_PERSON_VALUE;
    selectedCategoryValues = new Set();
    // TODO(backend-ready): Keep verified selections and explicit backend failure states.
    representableChildren = [];
    representationLoadFailed = false;
    representationLoaded = false;
    pageReference;
    requestedPersonValue = SELF_PERSON_VALUE;

    refreshInbox = () => {
        if (!this.isOnInbox) return;
        this.refreshPending = true;
        if (!this.wiredInbox) return;
        this.refreshPending = false;
        this.pageGeneration++;
        this.loadingMore = false;
        refreshApex(this.wiredInbox).catch((error) => {
            this.refreshFailed = true;
            console.error('Could not refresh inbox:', error);
        });
    };

    handleVisibility = () => {
        if (document.visibilityState === 'visible') this.refreshInbox();
    };

    connectedCallback() {
        window.addEventListener('pageshow', this.refreshInbox);
        window.addEventListener('focus', this.refreshInbox);
        window.addEventListener(READ_STATE_EVENT, this.refreshInbox);
        document.addEventListener('visibilitychange', this.handleVisibility);
    }

    disconnectedCallback() {
        window.removeEventListener('pageshow', this.refreshInbox);
        window.removeEventListener('focus', this.refreshInbox);
        window.removeEventListener(READ_STATE_EVENT, this.refreshInbox);
        document.removeEventListener('visibilitychange', this.handleVisibility);
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageReference) {
        this.isOnInbox = pageReference?.attributes?.name === 'Home';
        if (!this.isOnInbox) return;
        this.pageReference = pageReference;
        this.requestedPersonValue = pageReference.state?.c__inboxPerson || SELF_PERSON_VALUE;
        if (this.representationLoaded) {
            this.selectPerson(this.requestedPersonValue);
        }
        this.refreshInbox();
    }

    // TODO(backend-ready): Replace the scratch provider server-side and retain verified selections.
    @wire(getRepresentableChildren)
    wiredChildren({ data, error }) {
        if (error) {
            this.representationLoaded = true;
            this.representationLoadFailed = true;
            this.representableChildren = [];
            this.selectPerson(SELF_PERSON_VALUE);
            console.error('Could not load representable children:', error);
            return;
        }
        if (data === undefined) return;
        this.representationLoadFailed = false;
        this.representableChildren = data;
        this.representationLoaded = true;
        this.selectPerson(this.requestedPersonValue);
    }

    renderedCallback() {
        setDecoratorParams('Innboks', 'Innboks', '');
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

    @wire(getInboxPage, { representedAccountId: '$representedAccountId', beforeThreadId: null, beforeNoteId: null })
    wireInbox(result) {
        this.wiredInbox = result;
        if (result.error) {
            this.threads = [];
            this.recentthreads = [];
            console.error(result.error);
        } else if (result.data) {
            this.refreshFailed = false;
            this.applyPage(result.data, false);
        }
        if (this.refreshPending && (result.data || result.error)) this.refreshInbox();
    }

    applyPage(page, append) {
        const incomingIds = new Set([...page.older, ...page.recent].map((thread) => thread.recordId));
        this.threads = [
            ...(append ? (this.threads || []).filter((thread) => !incomingIds.has(thread.recordId)) : []),
            ...page.older
        ];
        this.recentthreads = [
            ...(append ? (this.recentthreads || []).filter((thread) => !incomingIds.has(thread.recordId)) : []),
            ...page.recent
        ];
        this.beforeThreadId = page.beforeThreadId;
        this.beforeNoteId = page.beforeNoteId;
        this.hasMore = page.hasMore;
        this.pageLoadFailed = false;
    }

    async handleLoadMore() {
        if (this.loadingMore || !this.hasMore) return;
        this.loadingMore = true;
        const generation = this.pageGeneration;
        try {
            const page = await getNextInboxPage({
                representedAccountId: this.representedAccountId,
                beforeThreadId: this.beforeThreadId || null,
                beforeNoteId: this.beforeNoteId || null
            });
            if (generation === this.pageGeneration) this.applyPage(page, true);
        } catch (error) {
            if (generation === this.pageGeneration) this.pageLoadFailed = true;
            console.error('Could not load more inbox messages:', error);
        } finally {
            if (generation === this.pageGeneration) this.loadingMore = false;
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
        this.selectPerson(event.detail?.value);
        this.requestedPersonValue = this.selectedPersonValue;
        if (this.pageReference) {
            const state = { ...this.pageReference.state };
            if (this.isSelfSelected) {
                delete state.c__inboxPerson;
            } else {
                state.c__inboxPerson = this.selectedPersonValue;
            }
            this[NavigationMixin.Navigate]({ ...this.pageReference, state }, true);
        }
    }

    selectPerson(value) {
        const validOption = this.personOptions.some((option) => option.value === value);

        const nextValue = validOption ? value : SELF_PERSON_VALUE;
        if (nextValue === this.selectedPersonValue) return;
        this.selectedPersonValue = nextValue;
        // TODO(backend-ready): Clear the previous person's content while the new query loads.
        this.threads = [];
        this.recentthreads = [];
        this.wiredInbox = undefined;
        this.beforeThreadId = undefined;
        this.beforeNoteId = undefined;
        this.hasMore = false;
        this.pageGeneration++;
        this.loadingMore = false;
        this.refreshPending = true;
        this.refreshFailed = false;
        this.pageLoadFailed = false;
        this.selectedCategoryValues = new Set();
    }

    getThreadCategory(thread) {
        return thread?.category?.trim() || '';
    }

    filterThreads(threads) {
        if (this.isAllCategoriesSelected) {
            return threads;
        }

        return threads.filter((thread) => this.selectedCategoryValues.has(this.getThreadCategory(thread)));
    }

    get selfPersonLabel() {
        return this.currentUserName ? `${this.currentUserName} (Deg)` : 'Deg';
    }

    get canRepresentChildren() {
        // TODO(backend-ready): Only server-verified responsibility should expose the dropdown.
        return this.representableChildren.length > 0;
    }

    get personOptions() {
        // TODO(backend-ready): Keep self plus authorized real Account IDs.
        return [{ label: this.selfPersonLabel, value: SELF_PERSON_VALUE }, ...this.representableChildren];
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

    get representedAccountId() {
        // TODO(backend-ready): Preserve null=self / Account ID=child contract.
        return this.isSelfSelected ? null : this.selectedPersonValue;
    }

    get isDataLoaded() {
        return this.wiredInbox?.data !== undefined;
    }

    // TODO(backend-ready): A success from one query must not hide a failure from the other query.
    get threadLoadFailed() {
        return Boolean(this.wiredInbox?.error || this.refreshFailed || this.pageLoadFailed);
    }

    get noItems() {
        // TODO(backend-ready): Loading/query failures are not empty inboxes.
        if (!this.isDataLoaded || this.threadLoadFailed || this.hasMore) {
            return false;
        }
        return !this.showVisibleRecentThreads && !this.showVisibleThreads;
    }

    get noItemsText() {
        return this.isSelfSelected
            ? 'Du har ingen meldinger i innboksen din.'
            : 'Det finnes ingen meldinger for denne personen.';
    }

    get personRecentThreads() {
        // TODO(backend-ready): Keep actual queried child messages; no mock arrays.
        const threads = this.recentthreads || [];

        return threads.filter(Boolean).sort(this.sortByDate);
    }

    get personThreads() {
        // TODO(backend-ready): Keep actual queried child history; no mock arrays.
        const threads = this.threads || [];

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

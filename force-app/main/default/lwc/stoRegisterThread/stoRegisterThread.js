import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import createThreadWithCase from '@salesforce/apex/stoHelperClass.createThreadWithCase';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import welcomelabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
import welcomelabelBTO from '@salesforce/label/c.Beskjed_til_oss_intro_text';
import acceptermtext from '@salesforce/label/c.Skriv_til_oss_Accept_terms_text';
import showtermstext from '@salesforce/label/c.Skriv_til_oss_Show_terms';
import textareadescription from '@salesforce/label/c.Skriv_til_oss_text_area_description';
import SERVICE_TERMS_HEADER from '@salesforce/label/c.STO_Skriv_til_oss_terms_header';
import SERVICE_TERMS from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text';
import SERVICE_TERMS_2 from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text_2';
import ACCEPT_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Accept_Terms_Button';
import ACCEPT_TERMS_ERROR from '@salesforce/label/c.Skriv_til_oss_Accept_terms_error_message';
import DENY_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Deny_Terms_Button';
import EMPTY_TEXT_FIELD_ERROR from '@salesforce/label/c.STO_Skriv_til_oss_text_field_empty_error';
import INCORRECT_CATEGORY from '@salesforce/label/c.STO_Incorrect_Category';
import { refreshApex } from '@salesforce/apex';
import { publish, MessageContext } from 'lightning/messageService';
import globalModalOpen from '@salesforce/messageChannel/globalModalOpen__c';
import basepath from '@salesforce/community/basePath';
import {
    AnalyticsEvents,
    logNavigationEvent,
    logButtonEvent,
    getComponentName,
    logFilterEvent,
    setDecoratorParams
} from 'c/inboxAmplitude';
import STO_HJELPEMIDLER_LABEL from '@salesforce/label/c.Skriv_til_oss_hjelpemidler_intro_text';

const maxThreadCount = 3;
const spinnerReasonTextMap = { send: 'Sender melding. Vennligst vent.', close: 'Avslutter samtale. Vennligst vent.' };

export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    @api threadTypeToMake;

    showspinner = false;
    category;
    themeToShow;
    acceptedcategories = new Set();
    currentPageReference = null;
    urlStateParameters;
    subpath;
    acceptedTerms = false;
    newsList;
    errorList = { title: '', errors: [] };
    message;
    modalOpen = false;
    maxLength = 2000;
    openThreadList;
    _title;

    label = {
        welcomelabel,
        welcomelabelBTO,
        acceptermtext,
        showtermstext,
        textareadescription,
        SERVICE_TERMS_HEADER,
        SERVICE_TERMS,
        SERVICE_TERMS_2,
        ACCEPT_TERMS_BUTTON,
        ACCEPT_TERMS_ERROR,
        DENY_TERMS_BUTTON,
        EMPTY_TEXT_FIELD_ERROR,
        INCORRECT_CATEGORY,
        STO_HJELPEMIDLER_LABEL
    };

    medskrivOptions = [
        { text: 'Ja, jeg godtar.', value: true, checked: false },
        { text: 'Nei, jeg godtar ikke.', value: false, checked: false }
    ];

    pleiepengerOptions = [
        { text: 'Ja', value: 'true', checked: false },
        { text: 'Nei', value: 'false', checked: false }
    ];

    logopath = navlogos + '/email.svg';
    deletepath = navlogos + '/delete.svg';
    wiredNews;
    wireThreadData;

    stoThemeMapping = {
        Arbeid: 'Arbeid',
        Familie: 'Familie og barn',
        Helse: 'Helse og sykdom',
        Hjelpemidler: 'Hjelpemidler og tilrettelegging',
        Internasjonal: 'Bor eller jobber i utlandet',
        Pensjon: 'Pensjon',
        Pleiepenger: 'Pleiepenger for sykt barn',
        Ufør: 'Ufør'
    };

    // TODO: Fill out rest
    btoThemeMapping = {
        'grunn-og-hjelpestonad': 'Grunnstønad eller hjelpestønad'
    };

    // TODO: Fill out rest
    // No category map needed for STO as it is equal to the url category param
    btoCategoryMap = {
        'dagpenger': 'Arbeid'
        'Endring-grunn-og-hjelpestonad': 'Helse'
    };

    ingressMap = {
        'Skriv til oss': {
            default: welcomelabel,
            Hjelpemidler: STO_HJELPEMIDLER_LABEL
        },
        'Gi beskjed': {
            default: '', // TODO: Label with Send oss opplysninger som ...
            'Internasjonal': '' // TODO: Label with Send oss opplysninger som ... + Er du over 65 år ...
        },
        'Meld fra om endring': {
            default: '', // TODO: Label with Send oss opplysninger som ...
            'Pensjon': '' // TODO: Du får en kvittering på at vi har mottatt beskjeden din
        },
        'Trekk en søknad': {
            default: '' // TODO: label with Hvilken søknad ønsker du å trekke?
        }
    };

    titleMap = {
        Endring: 'Meld fra om endring',
        'Trekke-soknad': 'Trekke en søknad',
        Beskjed: 'Gi beskjed'
    };

    connectedCallback() {
        getAcceptedThemes({ language: 'no' })
            .then((categoryResults) => {
                let categoryList = new Set();
                // TODO: Add all the potential categories here
                categoryResults.forEach((stoCategory) => {
                    categoryList.add(stoCategory.STO_Category__c);
                });
                this.acceptedcategories = categoryList;
            })
            .catch((error) => {
                console.error('Error fetching categories: ', error);
            });
    }

    renderedCallback() {
        if (this.showspinner) {
            let spinner = this.template.querySelector('.spinner');
            spinner.focus();
        }
    }

    @wire(MessageContext)
    messageContext;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.subpath =
                currentPageReference.attributes.name === 'Beskjed_til_oss__c' ? '/beskjed-til-oss/' : '/skriv-til-oss/';
            this.urlStateParameters = currentPageReference.state;

            const categoryParts = this.urlStateParameters.category.split('=')[1].split('-');
            const type = categoryParts.shift();
            const splitCategory = categoryParts.join('-');
            this.setTitleAndCategory(type, splitCategory);
            this.setThemeToShow(splitCategory);
            setDecoratorParams(this.title, this.themeToShow);
        }
    }

    @wire(getNews, { pageType: '$title', pageTheme: '$category' })
    wirednews(result) {
        const { data, error } = result;
        this.wiredNews = result;

        if (data) {
            this.newsList = result.data;
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getOpenThreads, { category: '$category', threadType: '$threadTypeToMake' })
    openThread(result) {
        const { error, data } = result;
        this.wireThreadData = result;

        if (data) {
            this.openThreadList = data;
        } else if (error) {
            console.error(error);
        }
    }

    get title() {
        return this._title;
    }

    @api
    set title(value) {
        this._title = value;
    }

    // TODO: Remove comment once acceptedCategories is valid
    get validparameter() {
        /*
        let valid = this.acceptedcategories.has(this.category);
        return valid;
        */
        return true;
    }

    get termsModal() {
        return this.template.querySelector('c-community-modal');
    }

    get termsContentText() {
        return this.label.SERVICE_TERMS + this.label.SERVICE_TERMS_2;
    }

    get showOpenThreadWarning() {
        return !!this.openThreadList?.length;
    }

    get openThreadText() {
        if (this.openThreadList.length < maxThreadCount) {
            return `Du har allerede åpne samtaler om ${this.category.toLowerCase()}. Hvis du lurer på noe mer, kan du <a href="${
                this.openThreadLink
            }">fortsette dine åpne samtaler</a>. Du kan ikke ha mer enn 3 åpne samtaler samtidig.`;
        }
        return `Du har ${
            this.openThreadList.length
        } åpne samtaler om ${this.category.toLowerCase()}. Du kan maksimalt ha 3 åpne samtaler. Hvis du vil opprette en ny samtale, må du derfor avslutte noen av de du allerede har.`;
    }

    get openThreadLink() {
        return this.threadTypeToMake === 'BTO'
            ? basepath + this.subpath + 'visning?samtale=' + this.openThreadList[0].recordId
            : basepath + this.subpath + this.openThreadList[0].recordId;
    }

    get alertType() {
        return this.openThreadList.length >= maxThreadCount ? 'advarsel' : 'info';
    }

    get showTextArea() {
        return (
            this.openThreadList == null ||
            this.openThreadList.length < maxThreadCount
        );
    }

    get backdropClass() {
        return this.hideDeleteModal ? 'slds-hide' : 'backdrop';
    }

    ingressMap = {
        'Skriv til oss': {
            default: welcomelabel,
            Hjelpemidler: STO_HJELPEMIDLER_LABEL
        },
        'Gi beskjed': {
            default: '', // TODO: Label with Send oss opplysninger som ...
            'Internasjonal': '' // TODO: Label with Send oss opplysninger som ... + Er du over 65 år ...
        },
        'Meld fra om endring': {
            default: '', // TODO: Label with Send oss opplysninger som ...
            'Pensjon': '' // TODO: Du får en kvittering på at vi har mottatt beskjeden din
        },
        'Trekk en søknad': {
            default: '' // TODO: label with Hvilken søknad ønsker du å trekke?
        }
    };

    get ingressLabel() {
        return this.ingressMap[this.title]?.[this.category] ?? this.ingressMap[this.title].['default'];
    }

    get showPleiepengerRadioButton() {
        return (
            this.threadTypeToMake === 'STO' &&
            (this.themeToShow === 'Helse og sykdom' || this.themeToShow === 'Familie og barn')
        );
    }

    setThemeToShow(splitUrlCategory) {
        this.themeToShow = this.threadTypeToMake === 'STO' ? this.stoThemeMapping[splitUrlCategory] : this.btoThemeMapping[splitUrlCategory];
    }

    getOriginalUrlCategoryBasedOnPleiepengerRadioButton() {
        if (this.urlStateParameters.category === 'Helse') {
            return 'Helse og sykdom';
        } else if (this.urlStateParameters.category === 'Familie') {
            return 'Familie og barn';
        }
        return 'Pleiepenger for sykt barn';
    }

    setTitleAndCategory(type, splitUrlCategory) {
        if (!this.urlStateParameters?.category) return;
        this._title = this.titleMap[type];
        // Special case since hjelpemidler url category is already taken for HOT inquiries
        if (this.urlStateParameters.category === 'Helse-hjelpemidler') { // TODO: Not decided what URL will be yet
            this.category = 'Helse';
            return;
        }
        // For STO the url category will be the same as the queue name
        this.category = this.threadTypeToMake === 'STO' this.urlStateParameters.category : this.btoCategoryMap[splitUrlCategory];
    }

    togglechecked() {
        this.acceptedTerms = !this.acceptedTerms;
    }

    showTerms() {
        this.modalOpen = true;
        this.termsModal.focusModal();
        publish(this.messageContext, globalModalOpen, { status: 'true' });
    }

    closeTerms() {
        this.modalOpen = false;
        const btn = this.template.querySelector('.focusBtn');
        btn.focus();
        publish(this.messageContext, globalModalOpen, { status: 'false' });
    }

    termsAccepted() {
        this.acceptedTerms = true;
        this.closeTerms();
        this.sendChecked();
    }

    termsDenied() {
        this.acceptedTerms = false;
        this.closeTerms();
        this.sendChecked();
    }

    /**
     * Handles terms modal end
     */
    navigateToBTO(thread) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Visning__c'
            },
            state: {
                samtale: thread.Id
            }
        });
    }

    /**
     * Creates a Thread record, with an message attached, and then navigates the user to the record page
     * @Author Lars Petter Johnsen
     */
    submitRequest() {
        const medskriv = this.template.querySelector('.medskrive')?.getValue();
        if (
            this.acceptedTerms &&
            this.message &&
            this.message.length != null &&
            this.message.length <= this.maxLength &&
            medskriv != null
        ) {
            this.showspinner = true;
            this.spinnerText = spinnerReasonTextMap.send;

            createThreadWithCase({
                theme: this.category,
                msgText: this.message,
                medskriv: medskriv,
                type: this.threadTypeToMake,
                inboxType: this.title,
                inboxTheme: this.pleiePengerSelected ? getOriginalUrlCategoryBasedOnPleiepengerRadioButton() : this.themeToShow
            })
                .then((thread) => {
                    this.showspinner = false;
                    if (this.threadTypeToMake === 'BTO') {
                        this.navigateToBTO(thread);
                    } else {
                        // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
                        window.open(
                            (this.linkUrl =
                                basepath + this.subpath + thread.Id + '/' + encodeURIComponent(thread.Name)),
                            '_self'
                        );
                    }

                    logButtonEvent(
                        AnalyticsEvents.FORM_COMPLETED,
                        'Send',
                        getComponentName(this.template),
                        this.title,
                        'ny samtale'
                    );
                })
                .catch((err) => {
                    console.error(err);
                    this.template.querySelector('c-alertdialog').showModal();
                    this.showspinner = false;
                });
        } else {
            this.errorList = { title: 'Du må fikse disse feilene før du kan sende inn meldingen.', errors: [] };
            if (!this.message || this.message.length == null) {
                this.errorList.errors.push({
                    Id: 1,
                    EventItem: '.inputTextbox',
                    Text: 'Tekstboksen kan ikke være tom.'
                });
            } else if (this.message.length >= this.maxLength) {
                this.errorList.errors.push({
                    Id: 2,
                    EventItem: '.inputTextbox',
                    Text: 'Det er for mange tegn i tekstboksen.'
                });
            }
            if (!this.acceptedTerms) {
                this.errorList.errors.push({
                    Id: 3,
                    EventItem: '.checkboxContainer',
                    Text: 'Du må godta vilkårene.'
                });
            }
            if (medskriv == null) {
                this.errorList.errors.push({
                    Id: 4,
                    EventItem: '.radioFocus',
                    Text: 'Du må velge et av alternativene.'
                });
            }
            let errorSummary = this.template.querySelector('.errorSummary');
            errorSummary.focusHeader();
        }
    }

    closeSelectedThread(selectedThreadId) {
        this.showspinner = true;
        this.spinnerText = spinnerReasonTextMap.close;
        closeThread({ id: selectedThreadId })
            .then(() => {
                refreshApex(this.wireThreadData)
                    .then(() => {
                        this.showspinner = false;
                    })
                    .catch((err) => {
                        console.log(err);
                    });
            })
            .catch((err) => {
                console.log(err);
            });
    }

    handleErrorClick(event) {
        let item = this.template.querySelector(event.detail);
        item.focus();
    }

    handleTextChange(event) {
        this.message = event.detail;
    }

    sendChecked() {
        let checkbox = this.template.querySelector('c-community-checkbox');
        checkbox.setChecked(this.acceptedTerms);
    }

    handleChecked(event) {
        this.acceptedTerms = event.detail;
    }

    handleKeyboardEvent(event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            this.closeTerms();
        }
    }

    handleFocusLast() {
        this.template.querySelector('.lastFocusElement').focus();
    }

    handleCloseThread(e) {
        const selectedThread = this.openThreadList[e.detail];
        if (selectedThread.recordId) {
            this.closeSelectedThread(selectedThread.recordId);
        }
    }

    handleRadioChange(event) {
        logFilterEvent(
            'Godtar du at vi kan bruke samtalen din til opplæring av veiledere i Nav?',
            event.detail.text,
            getComponentName(this.template),
            this.title
        );
    }

    handleAlterBoxClick() {
        const regex = /href="([^"]*)"/;
        const match = regex.exec(this.openThreadText);

        if (match[1]) {
            const hrefValue = match[1];
            logNavigationEvent(getComponentName(this.template), 'modal', hrefValue, 'fortsette dine åpne samtaler');
        } else {
            console.log('No href found in the openThreadText');
        }
    }

    pleiePengerSelected = false;
    handlePleiepengerChange(event) {
        if (event.detail.value === 'true') {
            this.pleiePengerSelected = true;
            this.category = 'Pleiepenger';
        }

        logFilterEvent(
            'Gjelder det pleiepenger for sykt barn?',
            event.detail.text,
            getComponentName(this.template),
            this.title
        );
    }
}

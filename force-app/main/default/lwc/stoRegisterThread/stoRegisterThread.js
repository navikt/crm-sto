import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import createThreadWithCase from '@salesforce/apex/stoHelperClass.createThreadWithCase';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
import welcomelabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
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
import STO_HJELPEMIDLER_INGRESS from '@salesforce/label/c.Skriv_til_oss_Hjelpemidler_ingress';
import ENDRING_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Endring_Default_ingress';
import ENDRING_PENSJON_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Endring_Pensjon_ingress';
import TREKK_SOKNAD_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Trekk_soknad_Default_ingress';
import BESKJED_INTERNASJONAL_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Internasjonal_ingress';
import BESKJED_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Default_ingress';
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
        INCORRECT_CATEGORY
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
        ventelonn: 'Ventelønn',
        'grunn-og-hjelpestonad': 'Grunnstønad eller hjelpestønad',
        yrkesskadetrygd: 'Frivillig yrkesskadetrygd'
    };

    // No category map needed for STO as it is equal to the url category param
    btoCategoryMap = {
        dagpenger: 'Arbeid',
        tiltakspenger: 'Arbeid',
        ventelonn: 'Arbeid',
        'grunn-og-hjelpestonad': 'Helse',
        yrkesskadetrygd: 'Helse',
        'omsorg-fosterhjem': 'Familie',
        arbeidsevne: 'Arbeid',
        enslig: 'Familie',
        barnetrygd: 'Familie',
        kontantstotte: 'Familie',
        bidrag: 'Familie',
        uforetrygd: 'Ufør',
        tilleggsstonader: 'Arbeid',
        aap: 'Arbeid',
        foreldre: 'Familie',
        'sykdom-familien': 'Familie',
        'AFP-offentlig': 'Pensjon',
        'supplerende-stonad-flyktninger': 'Ufør',
        'supplerende-stonad-over-67': 'Pensjon',
        alderspensjon: 'Pensjon',
        gjenlevende: 'Pensjon',
        sykepenger: 'Helse',
        arbeid: 'Arbeid',
        helse: 'Helse',
        utland: 'Internasjonal',
        familie: 'Familie',
        pensjon: 'Pensjon',
        hjelpemidler: 'Hjelpemidler',
        ufor: 'Ufør',
        trygdeavgift: 'Internasjonal',
        menerstatning: 'Helse',
        'AFP-privat': 'Pensjon'
    };

    ingressMap = {
        'Skriv til oss': {
            default: welcomelabel,
            Hjelpemidler: STO_HJELPEMIDLER_INGRESS
        },
        'Gi beskjed': {
            default: BESKJED_DEFAULT_INGRESS,
            Internasjonal: BESKJED_INTERNASJONAL_INGRESS
        },
        'Meld fra om endring': {
            default: ENDRING_DEFAULT_INGRESS,
            Pensjon: ENDRING_PENSJON_INGRESS
        },
        'Trekk en søknad': {
            default: TREKK_SOKNAD_DEFAULT_INGRESS
        }
    };

    titleMap = {
        Endring: 'Meld fra om endring',
        'Trekke-soknad': 'Trekke en søknad',
        Beskjed: 'Gi beskjed',
        'Andre-hjelpemidler': 'Skriv til oss'
    };

    connectedCallback() {
        getAcceptedThemes({ language: 'no' })
            .then((categoryResults) => {
                let categoryList = new Set();
                categoryResults.forEach((stoCategory) => {
                    categoryList.add(stoCategory.STO_Category__c);
                });
                this.acceptedcategories = categoryList;
                // TODO: Add url categories for BTO
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

            const categoryParts = this.urlStateParameters?.category.split('-');
            this.setTitleAndCategory(categoryParts);
            this.setThemeToShow(categoryParts);
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
    // TODO: Add another check for BTO url categories
    get validparameter() {
        /*
        let valid = this.acceptedcategories.has(this.category); // Valid for STO
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
            return `Du har allerede åpne samtaler om ${this.category?.toLowerCase()}. Hvis du lurer på noe mer, kan du <a href="${
                this.openThreadLink
            }">fortsette dine åpne samtaler</a>. Du kan ikke ha mer enn 3 åpne samtaler samtidig.`;
        }
        return `Du har ${
            this.openThreadList.length
        } åpne samtaler om ${this.category?.toLowerCase()}. Du kan maksimalt ha 3 åpne samtaler. Hvis du vil opprette en ny samtale, må du derfor avslutte noen av de du allerede har.`;
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
        return this.openThreadList == null || this.openThreadList.length < maxThreadCount;
    }

    get backdropClass() {
        return this.hideDeleteModal ? 'slds-hide' : 'backdrop';
    }

    get ingressLabel() {
        if (this.urlStateParameters.category === 'Andre-hjelpemidler') {
            return this.ingressMap[this.title]?.['Hjelpemidler'];
        }
        return this.ingressMap[this.title]?.[this.category] ?? this.ingressMap[this.title]?.['default'];
    }

    get showPleiepengerRadioButton() {
        return (
            this.threadTypeToMake === 'STO' &&
            (this.themeToShow === 'Helse og sykdom' || this.themeToShow === 'Familie og barn')
        );
    }

    setThemeToShow(splitUrlCategory) {
        if (!splitUrlCategory) return;

        let categoryString;
        if (splitUrlCategory.length > 1) {
            splitUrlCategory.shift(); // Remove type
            categoryString = splitUrlCategory.join('-');
        } else {
            categoryString = splitUrlCategory.join('-');
        }

        if (this.urlStateParameters.category === 'Andre-hjelpemidler') {
            this.themeToShow = 'Hjelpemidler';
            return;
        }

        this.themeToShow =
            this.threadTypeToMake === 'STO'
                ? this.stoThemeMapping[categoryString]
                : this.btoThemeMapping[categoryString];
    }

    setTitleAndCategory(splitUrlCategory) {
        if (!splitUrlCategory) return;
        let categoryString = splitUrlCategory.join('-');
        let type = splitUrlCategory[0];

        // Special case since hjelpemidler url category is already taken for HOT inquiries
        if (this.urlStateParameters.category === 'Andre-hjelpemidler') {
            this._title = this.titleMap['Andre-hjelpemidler'];
            this.category = 'Helse';
            return;
        }
        // Only one category e.g. "Helse" - valid for both BTO & STO
        if (splitUrlCategory.length === 1) {
            this.category = categoryString;
        }
        // New BTO category e.g. "Endring-arbeidsevne"
        if (splitUrlCategory.length > 1) {
            type = splitUrlCategory.shift();
            categoryString = splitUrlCategory.join('-');
            this.category = this.btoCategoryMap[categoryString];
        }
        this._title = this.titleMap[type] ?? 'Skriv til oss'; // If title not found -> it is STO
    }

    getOriginalUrlCategoryBasedOnPleiepengerRadioButton() {
        if (this.category === 'Helse') {
            return 'Helse og sykdom';
        } else if (this.category === 'Familie') {
            return 'Familie og barn';
        }
        return 'Pleiepenger for sykt barn';
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
                inboxTheme: this.pleiePengerSelected
                    ? this.getOriginalUrlCategoryBasedOnPleiepengerRadioButton()
                    : this.themeToShow
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
    previousCategory = null;
    handlePleiepengerChange(event) {
        if (event.detail.value) {
            if (!this.pleiePengerSelected) {
                this.previousCategory = this.category; // Store the current category
            }
            this.pleiePengerSelected = true;
            this.category = 'Pleiepenger';
        } else {
            this.pleiePengerSelected = false;
            this.category = this.previousCategory;
            this.previousCategory = null; // Reset to prevent incorrect reuse
        }

        logFilterEvent(
            'Gjelder det pleiepenger for sykt barn?',
            event.detail.text,
            getComponentName(this.template),
            this.title
        );
    }
}

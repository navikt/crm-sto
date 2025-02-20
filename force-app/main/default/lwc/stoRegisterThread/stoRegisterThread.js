import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import createThreadWithCase from '@salesforce/apex/stoHelperClass.createThreadWithCase';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
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
import STO_DEFAULT_INGRESS from '@salesforce/label/c.Skriv_til_oss_Default_ingress';
import STO_HJELPEMIDLER_INGRESS from '@salesforce/label/c.Skriv_til_oss_Hjelpemidler_ingress';
import BTO_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Default_ingress';
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
    acceptedSTOCategories = new Set();
    acceptedBTOCategories = [];
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

    // No category map needed for STO as it is equal to the url category param
    btoCategoryAndThemeMap = {
        // Melde fra om endring
        Endring: {
            dagpenger: { category: 'Arbeid', theme: 'Dagpenger' },
            tiltakspenger: { category: 'Arbeid', theme: 'Tiltakspenger' },
            ventelonn: { category: 'Arbeid', theme: 'Ventelønn' },
            'grunn-og-hjelpestonad': { category: 'Helse', theme: 'Grunnstønad eller hjelpestønad' },
            yrkesskadetrygd: { category: 'Helse', theme: 'Frivillig yrkesskadetrygd' },
            'omsorg-fosterhjem': { category: 'Familie', theme: 'Omsorgsstønad eller fosterhjemsgodtgjørelse' },
            arbeidsevne: { category: 'Arbeid', theme: 'Vurdering av arbeidsevne' },
            enslig: {
                category: 'Familie',
                theme: 'Overgangsstønad, stønad til barnetilsyn, stønad til skolepenger og tilleggsstønader til enslig mor eller far'
            },
            barnetrygd: { category: 'Familie', theme: 'Barnetrygd og utvidet barnetrygd' },
            kontantstotte: { category: 'Familie', theme: 'Kontantstøtte' },
            bidrag: { category: 'Familie', theme: 'Bidragsforskudd eller ektefellebidrag' },
            uforetrygd: { category: 'Ufør', theme: 'Uføretrygd' },
            tilleggsstonader: { category: 'Arbeid', theme: 'Tilleggsstønader' },
            aap: { category: 'Arbeid', theme: 'Arbeidsavklaringspenger (AAP)' },
            foreldre: { category: 'Familie', theme: 'Foreldrepenger, svangerskapspenger eller engangsstønad' },
            'sykdom-familien': { category: 'Familie', theme: 'Pleiepenger, omsorgspenger eller opplæringspenger' },
            'AFP-offentlig': { category: 'Pensjon', theme: 'AFP i offentlig sektor' },
            'supplerende-stonad-flyktninger': {
                category: 'Ufør',
                theme: 'Supplerende stønad for uføre flyktninger under 67 år'
            },
            'supplerende-stonad-over-67': {
                category: 'Pensjon',
                theme: 'Supplerende stønad for personer over 67 år med kort botid i Norge'
            },
            alderspensjon: { category: 'Pensjon', theme: 'Alderspensjon' },
            gjenlevende: { category: 'Pensjon', theme: 'Støtte til gjenlevende' },
            sykepenger: { category: 'Helse', theme: 'Sykepenger eller reisetilskudd' }
        },
        // Trekke en søknad
        'Trekke-soknad': {
            arbeid: { category: 'Arbeid', theme: 'Arbeid' },
            helse: { category: 'Helse', theme: 'Helse og sykdom' },
            utland: { category: 'Internasjonal', theme: 'Bor eller jobber i utlandet' },
            familie: { category: 'Familie', theme: 'Familie og barn' },
            pensjon: { category: 'Pensjon', theme: 'Pensjon' },
            hjelpemidler: { category: 'Hjelpemidler', theme: 'Hjelpemidler og tilrettelegging' },
            ufor: { category: 'Ufør', theme: 'Ufør' }
        },
        // Gi beskjed
        Beskjed: {
            trygdeavgift: { category: 'Internasjonal', theme: 'Be om bekreftelse på trygdeavgift' },
            sykepenger: { category: 'Helse', theme: 'Sykepenger' },
            menerstatning: { category: 'Helse', theme: 'Menerstatning' },
            'AFP-offentlig': { category: 'Pensjon', theme: 'AFP i offentlig sektor' },
            'AFP-privat': { category: 'Pensjon', theme: 'AFP i privat sektor' }
        }
    };

    ingressMap = {
        'Skriv til oss': {
            default: STO_DEFAULT_INGRESS,
            'Andre-hjelpemidler': STO_HJELPEMIDLER_INGRESS
        },
        'Beskjed til oss': {
            default: BTO_DEFAULT_INGRESS
        },
        'Gi beskjed': {
            default: BESKJED_DEFAULT_INGRESS,
            Internasjonal: BESKJED_INTERNASJONAL_INGRESS
        },
        'Meld fra om endring': {
            default: ENDRING_DEFAULT_INGRESS,
            Pensjon: ENDRING_PENSJON_INGRESS
        },
        'Trekke en søknad': {
            default: TREKK_SOKNAD_DEFAULT_INGRESS
        }
    };

    titleMap = {
        Endring: 'Meld fra om endring',
        'Trekke-soknad': 'Trekke en søknad',
        Beskjed: 'Gi beskjed'
    };

    wrongLinkMsg = '';
    connectedCallback() {
        getAcceptedThemes({ language: 'no' })
            .then((categoryResults) => {
                let categoryList = new Set();
                categoryResults.forEach((stoCategory) => {
                    categoryList.add(stoCategory.STO_Category__c);
                });
                this.acceptedSTOCategories = categoryList;
                this.acceptedSTOCategories.add('Andre-hjelpemidler'); // Special case
                // eslint-disable-next-line
                this.acceptedBTOCategories = Object.entries(this.btoCategoryAndThemeMap).flatMap(
                    ([parentKey, childObj]) => Object.keys(childObj).map((childKey) => `${parentKey}-${childKey}`)
                );
                this.wrongLinkMsg = 'Ops, denne lenken fungerte ikke.'; // Set text after getters have recalculated to avoid showing it before page is finished loading
            })
            .catch((error) => {
                console.error('Error fetching categories: ', error);
            });
    }

    renderedCallback() {
        if (this.showspinner) {
            this.template.querySelector('.spinner')?.focus();
        }
        document.title = this.tabName;
    }

    @wire(MessageContext)
    messageContext;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.subpath =
                currentPageReference.attributes.name === 'Beskjed_til_oss__c' ? '/beskjed-til-oss/' : '/skriv-til-oss/';
            this.urlStateParameters = currentPageReference.state;
            if (this.urlStateParameters?.category == null) {
                return;
            }
            this.setTitleAndCategory(this.urlStateParameters.category);
            this.setThemeToShow(this.urlStateParameters.category);
            setDecoratorParams(this.threadTypeToMake, this.title, this.themeToShow);
        }
    }

    @wire(getNews, { pageTitle: '$title', pageTheme: '$themeToShow' })
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
        } else {
            this.openThreadList = null; // Set to null when no data for pleiepenger radiobutton
            if (error) {
                console.error(error);
            }
        }
    }

    get tabName() {
        return `${this.title}${this.themeToShow ? ' - ' + this.themeToShow : ''}`;
    }

    get title() {
        return this._title;
    }

    @api
    set title(value) {
        this._title = value;
    }

    get validQueryParameter() {
        return this.isValidSTOCategory || this.isValidBTOCategory;
    }

    get isValidSTOCategory() {
        return this.threadTypeToMake === 'STO' && this.acceptedSTOCategories.has(this.urlStateParameters?.category);
    }

    // TODO: Remove this.acceptedSTOCategories.has(this.urlStateParameters?.category) when team PB is done adding new links for BTO so that we do not support the old BTO links anymore
    get isValidBTOCategory() {
        return (
            this.threadTypeToMake === 'BTO' &&
            (this.acceptedBTOCategories.includes(this.urlStateParameters?.category) ||
                this.acceptedSTOCategories.has(this.urlStateParameters?.category))
        );
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
        if (!this.openThreadList) return '';
        const openThreads = this.openThreadList.length;
        return openThreads < maxThreadCount
            ? `Du har allerede åpne samtaler om ${this.category?.toLowerCase()}. Hvis du lurer på noe mer, kan du <a href="${
                  this.openThreadLink
              }">fortsette dine åpne samtaler</a>. Du kan ikke ha mer enn 3 åpne samtaler samtidig.`
            : `Du har ${openThreads} åpne samtaler om ${this.category?.toLowerCase()}. Du kan maksimalt ha 3 åpne samtaler. Hvis du vil opprette en ny samtale, må du derfor avslutte noen av de du allerede har.`;
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
        if (this.urlStateParameters?.category === 'Andre-hjelpemidler') {
            return this.ingressMap[this.title]?.['Andre-hjelpemidler'];
        }
        return this.ingressMap[this.title]?.[this.category] || this.ingressMap[this.title]?.default;
    }

    get showPleiepengerRadioButton() {
        return (
            this.threadTypeToMake === 'STO' &&
            (this.themeToShow === 'Helse og sykdom' || this.themeToShow === 'Familie og barn')
        );
    }

    get showInputTextArea() {
        return !this.showPleiepengerRadioButton || this.pleiepengerSelected != null;
    }

    setThemeToShow(urlCategory) {
        if (urlCategory === 'Andre-hjelpemidler') {
            this.themeToShow = 'Hjelpemidler';
            return;
        }

        let [type, ...categoryParts] = urlCategory.split('-');

        if (type === 'Trekke' && categoryParts[0] === 'soknad') {
            type = 'Trekke-soknad';
            categoryParts.shift();
        }

        this.themeToShow =
            this.btoCategoryAndThemeMap[type]?.[categoryParts.join('-')]?.theme || this.stoThemeMapping[urlCategory];
    }

    setTitleAndCategory(urlCategory) {
        // Special case: "Andre-hjelpemidler" maps directly to "Helse" category.
        if (urlCategory === 'Andre-hjelpemidler') {
            this._title = 'Skriv til oss';
            this.category = 'Helse';
            return;
        }

        const splitUrlCategory = urlCategory.split('-');
        const hasMultipleParts = splitUrlCategory.length > 1;
        let type = splitUrlCategory[0];
        let categoryString = urlCategory;

        // New BTO category e.g. "Endring-arbeidsevne"
        if (hasMultipleParts) {
            const firstTwoWords = splitUrlCategory.slice(0, 2).join('-');

            if (firstTwoWords === 'Trekke-soknad') {
                // Special handling for "Trekke-soknad" case
                type = 'Trekke-soknad';
                categoryString = splitUrlCategory.slice(2).join('-');
            } else {
                // Default case: Extract type and category separately
                type = splitUrlCategory.shift();
                categoryString = splitUrlCategory.join('-');
            }
            this.category = this.btoCategoryAndThemeMap[type]?.[categoryString]?.category;
        } else {
            // Single-word category (valid for STO & BTO)
            this.category = categoryString;
        }
        this.previousCategory = this.category; // For pleiepenger radiobutton case

        // Set title
        this._title = this.titleMap[type] ?? (this.threadTypeToMake === 'STO' ? 'Skriv til oss' : 'Beskjed til oss');
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
        const medskriv = this.refs.medskrivRadiobuttons?.getValue();
        const pleiepenger = this.refs.pleiepengerRadiobutton?.getValue();
        const pleiepengerExists = this.refs.pleiepengerRadiobutton != null;

        if (
            this.acceptedTerms &&
            this.message &&
            this.message?.length != null &&
            this.message?.length <= this.maxLength &&
            medskriv != null &&
            (!pleiepengerExists || pleiepenger != null)
        ) {
            this.errorList = null;
            this.showspinner = true;
            this.spinnerText = spinnerReasonTextMap.send;

            createThreadWithCase({
                theme: this.category,
                msgText: this.message,
                medskriv: medskriv,
                type: this.threadTypeToMake,
                inboxTitle: this.title,
                inboxTheme: this.pleiepengerSelected
                    ? this.urlStateParameters?.category + '-Pleiepenger for sykt barn'
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
            if ((!this.message || this.message?.length == null) && this.showInputTextArea) {
                this.errorList.errors.push({
                    Id: 1,
                    EventItem: '.inputTextbox',
                    Text: 'Tekstboksen kan ikke være tom.'
                });
            } else if (this.message?.length >= this.maxLength && this.showInputTextArea) {
                this.errorList.errors.push({
                    Id: 2,
                    EventItem: '.inputTextbox',
                    Text: 'Det er for mange tegn i tekstboksen.'
                });
            }
            if (pleiepengerExists && pleiepenger == null) {
                this.errorList.errors.push({
                    Id: 3,
                    EventItem: '.pleiepenger',
                    Text: 'Du må velge et av alternativene.'
                });
            }
            if (medskriv == null) {
                this.errorList.errors.push({
                    Id: 4,
                    EventItem: '.medskrive',
                    Text: 'Du må velge et av alternativene.'
                });
            }
            if (!this.acceptedTerms) {
                this.errorList.errors.push({
                    Id: 5,
                    EventItem: '.checkboxContainer',
                    Text: 'Du må godta vilkårene.'
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
                        console.error(err);
                    });
            })
            .catch((err) => {
                console.error(err);
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

    handleAlertBoxClick() {
        const regex = /href="([^"]*)"/;
        const match = regex.exec(this.openThreadText);

        if (match && match[1]) {
            const hrefValue = match[1];
            logNavigationEvent(getComponentName(this.template), 'modal', hrefValue, 'fortsette dine åpne samtaler');
        } else {
            console.error('No href found in the openThreadText');
        }
    }

    previousCategory;
    pleiepengerSelected;
    handlePleiepengerChange(event) {
        if (event.detail.value === 'true') {
            this.pleiepengerSelected = true;
            this.previousCategory = this.category;
            this.category = 'Pleiepenger';
        } else {
            this.category = this.previousCategory;
            this.pleiepengerSelected = false;
        }

        logFilterEvent(
            'Gjelder det pleiepenger for sykt barn?',
            event.detail.text,
            getComponentName(this.template),
            this.title
        );
    }
}

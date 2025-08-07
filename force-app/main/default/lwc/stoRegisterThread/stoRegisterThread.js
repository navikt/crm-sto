import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import createThreadWithCase from '@salesforce/apex/stoHelperClass.createThreadWithCase';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getNewsBasedOnTheme';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';
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
import registerThreadTemplate from './registerThreadTemplate.html';
import badUrlTemplate from './badUrlTemplate.html';

import ACCEPT_TERM_TEXT from '@salesforce/label/c.Skriv_til_oss_Accept_terms_text';
import SHOW_TERM_TEXT from '@salesforce/label/c.Skriv_til_oss_Show_terms';
import SERVICE_TERMS_HEADER from '@salesforce/label/c.STO_Skriv_til_oss_terms_header';
import SERVICE_TERMS from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text';
import SERVICE_TERMS_2 from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text_2';
import ACCEPT_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Accept_Terms_Button';
import ACCEPT_TERMS_ERROR from '@salesforce/label/c.Skriv_til_oss_Accept_terms_error_message';
import DENY_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Deny_Terms_Button';
import EMPTY_TEXT_FIELD_ERROR from '@salesforce/label/c.STO_Skriv_til_oss_text_field_empty_error';
import INCORRECT_CATEGORY from '@salesforce/label/c.STO_Incorrect_Category';

import STO_DEFAULT_INGRESS from '@salesforce/label/c.Skriv_til_oss_Default_ingress';
import STO_HJELPEMIDLER_INGRESS from '@salesforce/label/c.Skriv_til_oss_Hjelpemidler_ingress';
import BTO_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Default_ingress';
import ENDRING_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Endring_Default_ingress';
import ENDRING_PENSJON_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Endring_Pensjon_ingress';
import TREKK_SOKNAD_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Trekk_soknad_Default_ingress';
import BESKJED_INTERNASJONAL_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Internasjonal_ingress';
import BESKJED_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Default_ingress';
import BESKJED_ARBEID_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Arbeid_ingress';
import BESKJED_KLAGE_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Klage_ingress';
import BESKJED_FRITA_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Frita_ingress';

const maxThreadCount = 3;
const spinnerReasonTextMap = { send: 'Sender melding. Vennligst vent.', close: 'Avslutter samtale. Vennligst vent.' };

export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    @api threadTypeToMake;

    render() {
        if (this.isLoading) {
            return null; // Show nothing until data is loaded
        }
        return this.validQueryParameter ? registerThreadTemplate : badUrlTemplate;
    }

    isLoading = true;
    showSpinner = false;
    category;
    themeToShow;
    acceptedSTOCategories = new Set();
    acceptedBTOCategories = [];
    currentPageReference = null;
    urlStateParameters;
    lowerCaseUrlCategory = '';
    subpath;
    acceptedTerms = false;
    newsList;
    errorList = { title: '', errors: [] };
    message;
    modalOpen = false;
    maxLength = 2000;
    openThreadList;
    _title;
    registerNewThread = false;

    labels = {
        ACCEPT_TERM_TEXT,
        SHOW_TERM_TEXT,
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

    radioButtonOptions = [
        { text: 'Ja', value: 'true', checked: false },
        { text: 'Nei', value: 'false', checked: false }
    ];

    logopath = navlogos + '/email.svg';
    deletepath = navlogos + '/delete.svg';
    wiredNews;
    wireThreadData;

    stoAndBtoThemeMapping = {
        arbeid: 'Arbeid',
        familie: 'Familie og barn',
        helse: 'Helse og sykdom',
        hjelpemidler: 'Hjelpemidler og tilrettelegging',
        internasjonal: 'Bor eller jobber i utlandet',
        pensjon: 'Pensjon',
        pleiepenger: 'Pleiepenger for sykt barn',
        ufør: 'Ufør'
    };

    // Uses type (prefix of category url) as key
    btoCategoryAndThemeMap = {
        // Melde fra om endring
        endring: {
            dagpenger: { category: 'Arbeid', theme: 'Dagpenger' },
            tiltakspenger: { category: 'Arbeid', theme: 'Tiltakspenger' },
            ventelonn: { category: 'Arbeid', theme: 'Ventelønn' },
            'grunn-og-hjelpestonad': { category: 'Helse', theme: 'Grunnstønad eller hjelpestønad' },
            yrkesskadetrygd: { category: 'Helse', theme: 'Frivillig yrkesskadetrygd' },
            'omsorg-fosterhjem': { category: 'Familie', theme: 'Omsorgsstønad eller fosterhjemsgodtgjørelse' },
            arbeidsevne: { category: 'Arbeid', theme: 'Vurdering av behov for oppfølging' },
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
            'afp-offentlig': { category: 'Pensjon', theme: 'AFP i offentlig sektor' },
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
        'trekke-soknad': {
            arbeid: { category: 'Arbeid', theme: 'Arbeid' },
            helse: { category: 'Helse', theme: 'Helse og sykdom' },
            utland: { category: 'Internasjonal', theme: 'Bor eller jobber i utlandet' },
            familie: { category: 'Familie', theme: 'Familie og barn' },
            pensjon: { category: 'Pensjon', theme: 'Pensjon' },
            hjelpemidler: { category: 'Hjelpemidler', theme: 'Hjelpemidler og tilrettelegging' },
            ufor: { category: 'Ufør', theme: 'Ufør' }
        },
        // Gi beskjed
        beskjed: {
            trygdeavgift: { category: 'Internasjonal', theme: 'Be om bekreftelse på trygdeavgift' },
            sykepenger: { category: 'Helse', theme: 'Sykepenger' },
            menerstatning: { category: 'Helse', theme: 'Menerstatning' },
            'afp-offentlig': { category: 'Pensjon', theme: 'AFP i offentlig sektor' },
            'afp-privat': { category: 'Pensjon', theme: 'AFP i privat sektor' },
            kontor: { category: 'Arbeid', theme: 'Avtale eller endre time på Nav-kontor' },
            'fullmakt-lege': { category: 'Helse', theme: 'Gi fullmakt til lege' },
            klage: { category: 'Arbeid', theme: 'Klage etter klagefrist' },
            taushetsplikt: { category: 'Arbeid', theme: 'Frita Nav fra taushetsplikten' }
        }
    };

    // Uses title as key
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
            'Be om bekreftelse på trygdeavgift': BESKJED_INTERNASJONAL_INGRESS,
            'Avtale eller endre time på Nav-kontor': BESKJED_ARBEID_INGRESS,
            'Gi fullmakt til lege': '', // kommer, settes i første omgang uten ingress
            'Klage etter klagefrist': BESKJED_KLAGE_INGRESS,
            'Frita Nav fra taushetsplikten': BESKJED_FRITA_INGRESS
        },
        'Meld fra om endring': {
            default: ENDRING_DEFAULT_INGRESS,
            'AFP i offentlig sektor': ENDRING_PENSJON_INGRESS
        },
        'Trekke en søknad': {
            default: TREKK_SOKNAD_DEFAULT_INGRESS
        }
    };

    // Uses type (prefix of category url) as key
    titleMap = {
        endring: 'Meld fra om endring',
        'trekke-soknad': 'Trekke en søknad',
        beskjed: 'Gi beskjed'
    };

    // Use title as primary key and themetoshow as secondary
    radioButtonMap = {
        'Skriv til oss': {
            'Helse og sykdom': {
                initialCategory: 'Helse',
                category: 'Pleiepenger',
                text: 'Gjelder det pleiepenger for sykt barn?',
                inboxTheme: 'Pleiepenger for sykt barn'
            },
            'Familie og barn': {
                initialCategory: 'Familie',
                category: 'Pleiepenger',
                text: 'Gjelder det pleiepenger for sykt barn?',
                inboxTheme: 'Pleiepenger for sykt barn'
            }
        },
        'Meld fra om endring': {
            'Pleiepenger, omsorgspenger eller opplæringspenger': {
                initialCategory: 'Familie',
                category: 'Pensjon',
                text: 'Gjelder det pleiepenger i livets sluttfase?',
                inboxTheme: 'Pleiepenger i livets sluttfase'
            }
        }
    };

    connectedCallback() {
        getAcceptedThemes({ language: 'no' })
            .then((categoryResults) => {
                let categoryList = new Set();
                categoryResults.forEach((stoCategory) => {
                    categoryList.add(stoCategory.STO_Category__c.toLowerCase());
                });
                this.acceptedSTOCategories = categoryList;
                this.acceptedSTOCategories.add('andre-hjelpemidler');
                // eslint-disable-next-line
                this.acceptedBTOCategories = Object.entries(this.btoCategoryAndThemeMap).flatMap(
                    ([parentKey, childObj]) =>
                        Object.keys(childObj).map((childKey) => `${parentKey}-${childKey}`.toLowerCase())
                );
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                console.error('Error fetching categories: ', error);
            });
    }

    renderedCallback() {
        if (this.showSpinner) {
            this.template.querySelector('.spinner')?.focus();
        }

        document.title = this.tabName;
        setDecoratorParams(this.threadTypeToMake, this.title, this.themeToShow);
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
            this.lowerCaseUrlCategory = this.urlStateParameters.category.toLowerCase();
            this.setTitleAndCategory();
            this.setThemeToShow();
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
            this.openThreadList = null; // Set to null when no data for radiobutton case
            if (error) {
                console.error(error);
            }
        }
    }

    setThemeToShow() {
        if (this.lowerCaseUrlCategory === 'andre-hjelpemidler') {
            this.themeToShow = 'Hjelpemidler';
            return;
        }

        let [type, ...categoryParts] = this.lowerCaseUrlCategory.split('-');

        if (type === 'trekke' && categoryParts[0] === 'soknad') {
            type = 'trekke-soknad';
            categoryParts.shift();
        }

        this.themeToShow =
            this.btoCategoryAndThemeMap[type]?.[categoryParts.join('-')]?.theme ||
            this.stoAndBtoThemeMapping[this.lowerCaseUrlCategory];
    }

    setTitleAndCategory() {
        // Special case: "Andre-hjelpemidler" maps directly to "Helse" category.
        if (this.lowerCaseUrlCategory === 'andre-hjelpemidler') {
            this._title = 'Skriv til oss';
            this.category = 'helse';
            return;
        }

        const splitUrlCategory = this.lowerCaseUrlCategory.split('-');
        const hasMultipleParts = splitUrlCategory.length > 1;
        let type = splitUrlCategory[0];
        let categoryString = this.lowerCaseUrlCategory;

        // New BTO category e.g. "Endring-arbeidsevne"
        if (hasMultipleParts) {
            const firstTwoWords = splitUrlCategory.slice(0, 2).join('-');

            if (firstTwoWords === 'trekke-soknad') {
                // Special handling for "Trekke-soknad" case
                type = 'trekke-soknad';
                categoryString = splitUrlCategory.slice(2).join('-');
            } else {
                // Default case: Extract type and category separately
                type = splitUrlCategory.shift();
                categoryString = splitUrlCategory.join('-');
            }
            this.category = this.btoCategoryAndThemeMap[type]?.[categoryString]?.category;
        } else {
            // No category map needed for old STO and BTO as STO_Category__c is equal to the one word url category param
            this.category = categoryString;
        }
        this.previousCategory = this.category; // For radiobutton cases

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
        const btn = this.template.querySelector('.vilkar-link');
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
    navigateToBTO() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Bekreftelsesvisning__c'
            }
        });
    }

    /**
     * Creates a Thread record, with an message attached, and then navigates the user to the record page
     * @Author Lars Petter Johnsen
     */
    submitRequest() {
        const medskriv = this.refs.medskrivRadiobuttons?.getValue();
        const radioButtonValue = this.refs.themeRadioButton?.getValue();
        const radioButtonExists = this.refs.themeRadioButton != null;

        if (
            this.acceptedTerms &&
            this.message &&
            this.message?.length != null &&
            this.message?.length <= this.maxLength &&
            medskriv != null &&
            (!radioButtonExists || radioButtonValue != null)
        ) {
            this.errorList = null;
            this.showSpinner = true;
            this.spinnerText = spinnerReasonTextMap.send;

            createThreadWithCase({
                theme: this.category,
                msgText: this.message,
                medskriv: medskriv,
                type: this.threadTypeToMake,
                inboxTitle: this.title,
                inboxTheme: this.themeRadioButtonSelected
                    ? this.capitalizeFirstLetter(this.radioButtonMap[this.title]?.[this.themeToShow]?.initialCategory) +
                      '-' +
                      this.radioButtonMap[this.title]?.[this.themeToShow]?.inboxTheme
                    : this.themeToShow
            })
                .then((thread) => {
                    this.showSpinner = false;
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
                    this.showSpinner = false;
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
            if (radioButtonExists && radioButtonValue == null) {
                this.errorList.errors.push({
                    Id: 3,
                    EventItem: '.themeRadioButton',
                    Text: 'Du må velge et av alternativene.'
                });
            }
            if (medskriv == null) {
                this.errorList.errors.push({
                    Id: 4,
                    EventItem: '.medskriv',
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

    handleCloseThread(e) {
        const selectedThread = this.openThreadList[e.detail];
        if (selectedThread.recordId) {
            this.closeSelectedThread(selectedThread.recordId);
        }
    }

    closeSelectedThread(selectedThreadId) {
        this.showSpinner = true;
        this.spinnerText = spinnerReasonTextMap.close;
        closeThread({ id: selectedThreadId })
            .then(() => {
                refreshApex(this.wireThreadData)
                    .then(() => {
                        this.showSpinner = false;
                    })
                    .catch((err) => {
                        console.error(err);
                    });
            })
            .catch((err) => {
                console.error(err);
            });
    }

    capitalizeFirstLetter(val) {
        return String(val).charAt(0).toUpperCase() + String(val).slice(1);
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
    themeRadioButtonSelected;
    handleThemeRadioButtonChange(event) {
        if (event.detail.value === 'true') {
            this.themeRadioButtonSelected = true;
            this.previousCategory = this.category;
            this.category = this.radioButtonMap[this.title]?.[this.themeToShow]?.category;
        } else {
            this.category = this.previousCategory;
            this.themeRadioButtonSelected = false;
        }

        logFilterEvent(
            this.radioButtonMap[this.title]?.[this.themeToShow]?.text,
            event.detail.text,
            getComponentName(this.template),
            this.title
        );
    }

    handleShowTextArea() {
        this.registerNewThread = true;
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
        return this.threadTypeToMake === 'STO' && this.acceptedSTOCategories.has(this.lowerCaseUrlCategory);
    }

    get isValidBTOCategory() {
        return this.threadTypeToMake === 'BTO' && this.acceptedBTOCategories.includes(this.lowerCaseUrlCategory);
    }

    get termsModal() {
        return this.template.querySelector('c-community-modal');
    }

    get termsContentText() {
        return this.labels.SERVICE_TERMS + this.labels.SERVICE_TERMS_2;
    }

    get showOpenThreadWarning() {
        return !!this.openThreadList?.length;
    }

    get openThreadText() {
        if (!this.openThreadList) return '';
        return this.canOpenMoreThreads
            ? `Vi ser at du allerede har ${this.openThreads} åpne meldinger på dette temaet. Ønsker du å fortsette på en tidligere melding eller ønsker du å skrive en ny?`
            : `Vi ser at du allerede har ${this.openThreads} åpne meldinger på dette temaet ${this.capitalizedCategory}. Du kan maks ha tre samtaler på hvert tema. Hvis du vil opprette en ny samtale, må du derfor avslutte en av de du allerede har.`;
    }

    get openThreadLink() {
        return this.threadTypeToMake === 'BTO'
            ? basepath + this.subpath + 'visning?samtale=' + this.openThreadList[0].recordId
            : basepath + this.subpath + this.openThreadList[0].recordId;
    }

    get alertType() {
        return this.openThreadList.length >= maxThreadCount && this.threadTypeToMake === 'STO' ? 'advarsel' : 'info';
    }

    get showTextArea() {
        return this.openThreadList == null || this.registerNewThread;
    }

    get ingressLabel() {
        if (this.lowerCaseUrlCategory === 'andre-hjelpemidler') {
            return this.ingressMap[this.title]?.['Andre-hjelpemidler'];
        }

        return this.ingressMap[this.title]?.[this.themeToShow] ?? this.ingressMap[this.title]?.default;
    }

    get showThemeRadioButton() {
        return this.radioButtonMap[this.title]?.[this.themeToShow] ?? false;
    }

    get themeRadioButtonText() {
        return this.radioButtonMap[this.title]?.[this.themeToShow]?.text;
    }

    get showInputTextArea() {
        return !this.showThemeRadioButton || this.themeRadioButtonSelected != null;
    }

    get capitalizedCategory() {
        return this.capitalizeFirstLetter(this.category);
    }

    get openThreads() {
        const length = this.openThreadList.length;
        const numberWords = {
            1: 'en',
            2: 'to',
            3: 'tre'
        };
        return numberWords[length] || length;
    }

    get canOpenMoreThreads() {
        return this.openThreads < maxThreadCount || this.threadTypeToMake === 'BTO';
    }
}

import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import createThreadWithCaseV2 from '@salesforce/apex/stoHelperClass.createThreadWithCaseV2';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getNewsBasedOnTheme';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
// TODO: Add import for getRepresentableChildren when ready.
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
import putCloseIntent from '@salesforce/apex/stoHelperClass.putCloseIntent';

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
import ENDRING_INTERNASJONAL_YRKESSKADE_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Endring_Internasjonal_Yrkesskade_ingress';
import TREKK_SOKNAD_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Trekk_soknad_Default_ingress';
import BESKJED_INTERNASJONAL_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Internasjonal_ingress';
import BESKJED_DEFAULT_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Default_ingress';
import BESKJED_ARBEID_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Arbeid_ingress';
import BESKJED_KLAGE_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Klage_ingress';
import BESKJED_FRITA_INGRESS from '@salesforce/label/c.Beskjed_til_oss_Beskjed_Frita_ingress';

const maxThreadCountSto = 3;
const maxThreadCountBto = 10;
const spinnerReasonTextMap = {
    send: 'Sender melding. Vennligst vent.',
    close: 'Avslutter samtale. Vennligst vent.',
    load: 'Laster samtaler. Vennligst vent.'
};
const SELF_PERSON_VALUE = 'self';

// TODO(representation-api): Remove these fixtures when the authorized children endpoint is available. Never send these values to Apex.
const MOCK_REPRESENTABLE_CHILDREN = [
    { label: 'Beate Normann (datter, 8 år)', value: 'mock-child-1' },
    { label: 'Ola Normann (sønn, 12 år)', value: 'mock-child-2' }
];

// STO: group-level eligibility from your requirement.
// NOTE: existing STO "Ufør" is treated as Uføretrygd.
const STO_REPRESENTATION_THEME_GROUPS = new Set([
    'Helse og sykdom',
    'Familie og barn',
    'Hjelpemidler og tilrettelegging',
    'Pensjon',
    'Ufør'
]);

// TODO(representation-policy): Confirm the final approved eligibility matrix. The frontend configuration must also be enforced by Apex.
const BTO_REPRESENTATION_RULES = {
    Familie: {
        mode: 'all',
        themes: new Set()
    },
    Helse: {
        mode: 'themes',
        themes: new Set(['Grunnstønad eller hjelpestønad', 'Yrkesskade'])
    },
    Pensjon: {
        mode: 'themes',
        themes: new Set(['Støtte til gjenlevende']) // ToDo: Confirm if this theme is correct
    },
    Ufør: {
        mode: 'themes',
        themes: new Set(['Uføretrygd'])
    }
};

// ToDo: To be replaced with actual logic for determining if the user has parental responsibility
const MOCK_HAS_FORELDREANSVAR = true;

const MOCK_REPRESENTATION_INGRESS =
    'Du kan sende meldinger til Nav på vegne av barna dine hvis du har foreldreansvar for dem. Når barn blir myndige (eller du mister foreldreretten), vil du ikke lenger kunne se meldinger du har sendt på deres vegne, eller ha dialog med Nav på deres vegne.';

export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    @api threadTypeToMake;

    isLoading = true;
    showSpinner = false;
    category;
    themeToShow;
    originalThemeToShow;
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
    openThreadList = [];
    _title;
    registerNewThread = false;
    isThreadDataLoading = true;
    showBTOConfirmation = false;

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
            sykepenger: { category: 'Helse', theme: 'Sykepenger eller reisetilskudd' },
            utland: { category: 'Internasjonal', theme: 'Bor eller jobber i utlandet' },
            yrkesskade: { category: 'Helse', theme: 'Yrkesskade' }
            // TODO(representation-routing): Add the approved Barnepensjon route with category 'Pensjon' and theme 'Barnepensjon'. Eligibility is configured, but no matching route exists here yet.
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
            representation: MOCK_REPRESENTATION_INGRESS, // ToDo: Replace with actual default representation ingress for STO when available
            'Andre-hjelpemidler': STO_HJELPEMIDLER_INGRESS // ToDo: Replace with actual Hjelpemidler representation ingress when available
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
            representation: MOCK_REPRESENTATION_INGRESS, // ToDo: Replace with actual default representation ingress for Meld fra om endring when available
            'AFP i offentlig sektor': ENDRING_PENSJON_INGRESS,
            'Bor eller jobber i utlandet': ENDRING_INTERNASJONAL_YRKESSKADE_INGRESS,
            Yrkesskade: ENDRING_INTERNASJONAL_YRKESSKADE_INGRESS // ToDo: Replace with actual Yrkesskade representation ingress when available
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
            },
            Ufør: {
                initialCategory: 'Ufør',
                category: 'Ufør',
                text: 'Har du fått SMS om at vi kan hjelpe deg å se på mulighetene dine?',
                inboxTheme: 'Ufør'
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

    // Person selection
    currentUserName = '';
    selectedPersonValue = SELF_PERSON_VALUE;
    personSelectionConfirmed = false;
    representationLoaded = false;
    representationLoadFailed = false;
    personSelectionError = '';
    threadLoadFailed = false;
    originalCategory;

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

    render() {
        if (this.isLoading) {
            return null;
        }
        return this.validQueryParameter ? registerThreadTemplate : badUrlTemplate;
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
            const nextCategory = this.urlStateParameters.category.toLowerCase();

            if (nextCategory !== this.lowerCaseUrlCategory) {
                this.resetPersonContext();
            }

            this.lowerCaseUrlCategory = nextCategory;
            this.setTitleAndCategory();
            this.setThemeToShow();

            this.originalCategory = this.category;
            this.originalThemeToShow = this.themeToShow;

            // TODO(representation-api): Replace local initialization with an authorized person lookup, including loading/error handling and stale-route protection.
            this.initializeMockPersons();
        }
    }

    @wire(getNews, { pageTitle: '$title', pageTheme: '$themeToShow' })
    wirednews(result) {
        const { data, error } = result;

        if (data) {
            this.newsList = data;
        } else if (error) {
            console.error(error);
        }
    }

    // TODO(representation-api): Extend Apex to accept representedPersonId, authorize the selected person, and return only that person's threads. Then add representedPersonId: '$representedPersonId' to this configuration.
    @wire(getOpenThreads, {
        category: '$threadQueryCategory',
        threadType: '$threadQueryType'
    })
    openThread(result) {
        if (!this.hasPersonContext || this.threadQueryCategory === undefined) {
            return;
        }

        const { data, error } = result;

        // A pending wire is not an empty thread list.
        if (data === undefined && !error) {
            this.isThreadDataLoading = true;
            this.spinnerText = spinnerReasonTextMap.load;
            return;
        }

        this.wireThreadData = result;
        this.isThreadDataLoading = false;

        if (error) {
            this.threadLoadFailed = true;
            this.openThreadList = [];
            this.registerNewThread = false;
            return;
        }

        this.threadLoadFailed = false;
        this.openThreadList = data || [];
        this.registerNewThread = this.openThreadList.length === 0 || this.showBtoTextArea;

        // TODO(representation-api): Confirm whether close intent is person-scoped or global. Align this operation with that backend contract.
        putCloseIntent({
            count: this.openThreadList.length
        }).catch(() => {
            console.error('Could not update close intent.');
        });
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

    initializeMockPersons() {
        // TODO(representation-api): Replace this method with the real person lookup. Include only children the authenticated user is authorized to represent. Keep "Meg selv" available when the response contains no children.
        this.representationLoaded = true;
        this.representationLoadFailed = false;
    }

    handlePersonChange(event) {
        // Required communityCombobox event contract: detail = { value }.
        const value = event.detail?.value;
        const validOption = this.personOptions.some((option) => option.value === value);

        this.selectedPersonValue = validOption ? value : '';
        this.personSelectionError = '';
    }

    handlePersonNext() {
        const validOption = this.personOptions.some((option) => option.value === this.selectedPersonValue);

        if (!validOption) {
            this.personSelectionError = 'Du må velge hvem du vil skrive på vegne av.';
            this.template.querySelector('c-community-combobox')?.focus();
            return;
        }

        this.errorList = { title: '', errors: [] };
        this.openThreadList = [];
        this.registerNewThread = false;
        this.threadLoadFailed = false;
        this.isThreadDataLoading = true;
        this.spinnerText = spinnerReasonTextMap.load;

        // Enables real self-only retrieval or the mock child form.
        // TODO(representation-api): Enable person-scoped retrieval for real children.
        this.personSelectionConfirmed = true;

        // TODO(representation-api): Remove this mock reset when person-scoped thread retrieval handles category changes and clears the loading state.
        if (this.isMockChildSelected) {
            this.applyMockChildThreads();
        }
    }

    resetPersonContext() {
        this.selectedPersonValue = SELF_PERSON_VALUE;
        this.personSelectionConfirmed = false;
        this.representationLoaded = false;
        this.representationLoadFailed = false;
        this.personSelectionError = '';
        this.threadLoadFailed = false;

        this.openThreadList = [];
        this.registerNewThread = false;
        this.isThreadDataLoading = true;
        this.wireThreadData = undefined;

        this.message = undefined;
        this.acceptedTerms = false;
        this.themeRadioButtonSelected = undefined;
        this.showBTOConfirmation = false;
        this.errorList = { title: '', errors: [] };
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
        publish(this.messageContext, globalModalOpen, { status: 'true' });
    }

    closeTerms() {
        this.modalOpen = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
        setTimeout(() => {
            const btn = this.template.querySelector('.vilkar-link');
            if (btn) btn.focus();
            publish(this.messageContext, globalModalOpen, { status: 'false' });
        }, 0);
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
     * Creates a Thread record, with an message attached, and then navigates the user to the record page
     * @Author Lars Petter Johnsen
     */
    submitRequest() {
        if (!this.hasPersonContext || this.threadLoadFailed || this.shouldShowSpinner) {
            return;
        }

        const medskriv = this.refs.medskrivRadiobuttons?.getValue();
        const radioButtonValue = this.refs.themeRadioButton?.getValue();
        const radioButtonExists = this.refs.themeRadioButton != null;
        const disabilityCampaign = radioButtonValue === 'true';

        let theme = this.category;
        let inboxTheme = this.themeToShow;

        // Only build inboxTheme from radioButtonMap if radio is actually selected "Ja"
        if (this.themeRadioButtonSelected) {
            // Use the original theme for robust mapping
            const radioMap = this.radioButtonMap[this.title]?.[this.originalThemeToShow];
            const initialCategory = radioMap?.initialCategory
                ? this.capitalizeFirstLetter(radioMap.initialCategory)
                : '';
            const mappedInboxTheme = radioMap?.inboxTheme;
            if (initialCategory && mappedInboxTheme) {
                inboxTheme = `${initialCategory}-${mappedInboxTheme}`;
            } else if (mappedInboxTheme) {
                inboxTheme = mappedInboxTheme;
            }
        }

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

            // TODO(representation-api): Add representedPersonId to the agreed Apex creation contract. Enforce person-scoped thread limits server-side.
            createThreadWithCaseV2({
                theme: theme,
                msgText: this.message,
                medskriv: medskriv,
                type: this.threadTypeToMake,
                inboxTitle: this.title,
                inboxTheme: inboxTheme,
                disabilityCampaign: disabilityCampaign
            })
                .then((thread) => {
                    this.showSpinner = false;
                    if (this.threadTypeToMake === 'BTO') {
                        this.showBTOConfirmation = true;
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
                    window.scrollTo({ top: 0, behavior: 'smooth' });
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
            } else if (this.message?.length > this.maxLength && this.showInputTextArea) {
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
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // TODO(representation-api): Verify Apex authorizes access to this thread for the authenticated user, including represented-person threads. After closing, refresh the same person-scoped thread query.
    async closeSelectedThread(selectedThreadId) {
        this.showSpinner = true;
        this.spinnerText = spinnerReasonTextMap.close;

        try {
            // Apex must authorize this specific thread before closing it.
            await closeThread({ id: selectedThreadId });
            await refreshApex(this.wireThreadData);
        } catch {
            this.template.querySelector('c-alertdialog')?.showModal();
        } finally {
            this.showSpinner = false;
        }
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
        if (this.title === 'Skriv til oss' && this.originalThemeToShow === 'Ufør') {
            this.themeRadioButtonSelected = event.detail.value === 'true';
            return;
        }
        this.isThreadDataLoading = true;
        this.spinnerText = spinnerReasonTextMap.load;
        const mappingKey = this.originalThemeToShow;
        if (event.detail.value === 'true') {
            this.themeRadioButtonSelected = true;
            this.previousCategory = this.category;
            const radioMap = this.radioButtonMap[this.title]?.[mappingKey];
            if (radioMap) {
                this.category = radioMap.category;
                this.themeToShow = radioMap.inboxTheme;
            }
            window.scrollTo({ top: 0, behavior: 'smooth' });
        } else {
            const prevCategory = this.category;
            const prevTheme = this.themeToShow;

            this.category = this.previousCategory;
            this.themeRadioButtonSelected = false;
            this.themeToShow = this.originalThemeToShow;

            if (prevCategory === this.category && prevTheme === this.themeToShow) {
                this.isThreadDataLoading = false;
            }
        }

        if (this.isMockChildSelected) {
            this.applyMockChildThreads();
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
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    handleSendSto() {
        // TODO(representation-navigation): Decide whether to ask for the person again on the STO page or restore a validated person context. Never silently change a child conversation into a self conversation.
        // eslint-disable-next-line @locker/locker/distorted-xml-http-request-window-open
        window.open(basepath + `/skriv-til-oss?category=${this.category}`, '_self');
    }

    get tabName() {
        return `${this.themeToShow ? this.themeToShow + ' - ' : ''}${this.title}`;
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

    get termsContentText() {
        return this.labels.SERVICE_TERMS + this.labels.SERVICE_TERMS_2;
    }

    get showOpenThreadWarning() {
        return !!this.openThreadList?.length;
    }

    get openThreadText() {
        if (!this.openThreadList) return '';

        if (this.threadTypeToMake === 'STO') {
            if (this.canOpenMoreThreads) {
                if (this.openThreads === 1) {
                    return `Vi ser at du allerede har ${this.openThreadsWord} åpen melding på dette temaet. Ønsker du å fortsette på denne meldingen eller skrive en ny?`;
                }
                return `Vi ser at du allerede har ${this.openThreadsWord} åpne meldinger på dette temaet. Ønsker du å fortsette på en tidligere melding eller skrive en ny?`;
            }
            return `Vi ser at du allerede har ${this.openThreadsWord} åpne meldinger på dette temaet ${this.capitalizedCategory}. Du kan maks ha tre samtaler på hvert tema. Hvis du vil opprette en ny samtale må du derfor avslutte en av de du allerede har.`;
        }
        return 'Du har nå nådd grensen på 10 åpne samtaler. Hvis du har flere opplysninger eller spørsmål til oss, kan du opprette en ny samtale via «skriv til oss»';
    }

    get openThreadLink() {
        return this.threadTypeToMake === 'BTO'
            ? basepath + this.subpath + 'visning?samtale=' + this.openThreadList[0].recordId
            : basepath + this.subpath + this.openThreadList[0].recordId;
    }

    get alertType() {
        return this.openThreadList?.length >= maxThreadCountSto && this.threadTypeToMake === 'STO'
            ? 'advarsel'
            : 'info';
    }

    get ingressLabel() {
        const ingress = this.ingressMap[this.title];

        if (this.allowsRepresentation && ingress?.representation) {
            return ingress.representation;
        }

        if (this.lowerCaseUrlCategory === 'andre-hjelpemidler') {
            return ingress?.['Andre-hjelpemidler'];
        }

        return ingress?.[this.themeToShow] ?? ingress?.default;
    }

    get showThemeRadioButton() {
        const mapping = this.radioButtonMap[this.title]?.[this.originalThemeToShow];
        if (!mapping) return false;
        return this.themeToShow === this.originalThemeToShow;
    }

    get themeRadioButtonText() {
        return this.radioButtonMap[this.title]?.[this.originalThemeToShow]?.text;
    }

    get showInputTextArea() {
        return !this.showThemeRadioButton || this.themeRadioButtonSelected != null;
    }

    get capitalizedCategory() {
        return this.capitalizeFirstLetter(this.category);
    }

    get openThreads() {
        return this.openThreadList?.length;
    }

    get openThreadsWord() {
        const length = this.openThreadList?.length;
        const numberWords = {
            1: 'en',
            2: 'to',
            3: 'tre'
        };
        return numberWords[length] || length;
    }

    get canOpenMoreThreads() {
        return this.openThreads < maxThreadCountSto || this.threadTypeToMake === 'BTO';
    }

    get shouldShowSpinner() {
        const loadingPeople = this.allowsRepresentation && !this.representationLoaded;

        const loadingThreads = this.hasPersonContext && this.isThreadDataLoading;

        return loadingPeople || loadingThreads || this.showSpinner;
    }

    get shouldShowTextArea() {
        return this.hasPersonContext && !this.threadLoadFailed && !this.isThreadDataLoading && this.registerNewThread;
    }

    get shouldShowThreads() {
        return (
            this.hasPersonContext &&
            !this.threadLoadFailed &&
            !this.isThreadDataLoading &&
            !this.registerNewThread &&
            !this.showBtoTextArea
        );
    }

    get btoConfirmationTitle() {
        const messages = {
            beskjed: 'Vi har mottatt meldingen din. Takk for at du tok kontakt.',
            endring: 'Endringen er registrert. Takk for at du ga beskjed.',
            'trekke-soknad': 'Vi har mottatt beskjed om at du ønsker å trekke søknaden. Takk for at du informerte oss.'
        };

        return Object.entries(messages).find(([key]) => this.lowerCaseUrlCategory?.includes(key))?.[1] || '';
    }

    get showBtoTextArea() {
        return this.threadTypeToMake === 'BTO' && this.openThreads < maxThreadCountBto;
    }

    get showSendSTOButton() {
        return this.threadTypeToMake === 'BTO' && this.openThreads >= maxThreadCountBto;
    }

    get showNewMessageButton() {
        return this.threadTypeToMake === 'STO' && this.canOpenMoreThreads;
    }

    get allowsRepresentation() {
        if (!this.canRepresentChildren) {
            return false;
        }

        if (this.threadTypeToMake === 'STO') {
            // The special Hjelpemidler route belongs to the same eligible group.
            const themeGroup =
                this.originalThemeToShow === 'Hjelpemidler'
                    ? 'Hjelpemidler og tilrettelegging'
                    : this.originalThemeToShow;

            return STO_REPRESENTATION_THEME_GROUPS.has(themeGroup);
        }

        if (this.threadTypeToMake === 'BTO') {
            const rule = BTO_REPRESENTATION_RULES[this.originalCategory];

            if (!rule) {
                return false;
            }

            return rule.mode === 'all' || rule.themes.has(this.originalThemeToShow);
        }

        return false;
    }

    /**
     * representation-related getters and logic.
     */

    get canRepresentChildren() {
        return MOCK_HAS_FORELDREANSVAR && MOCK_REPRESENTABLE_CHILDREN.length > 0;
    }

    get selfPersonLabel() {
        return this.currentUserName ? `Deg (${this.currentUserName})` : 'Deg';
    }

    get personOptions() {
        return [
            { label: this.selfPersonLabel, value: SELF_PERSON_VALUE },
            ...(this.canRepresentChildren ? MOCK_REPRESENTABLE_CHILDREN : [])
        ];
    }

    get isMockChildSelected() {
        // TODO(representation-api): Remove this fixture-specific getter once real child retrieval, threads, and submission are implemented together.
        return (
            this.personSelectionConfirmed &&
            MOCK_REPRESENTABLE_CHILDREN.some((child) => child.value === this.selectedPersonValue)
        );
    }

    applyMockChildThreads() {
        // TODO(representation-api): Replace this empty mock list with authorized, person-scoped threads. Do not reuse the logged-in user's thread list.
        this.openThreadList = [];
        this.wireThreadData = undefined;
        this.threadLoadFailed = false;
        this.isThreadDataLoading = false;
        this.registerNewThread = true;
    }

    get threadQueryCategory() {
        // TODO(representation-api): Once Apex supports person-scoped retrieval, remove the mock-child exclusion and pass representedPersonId to the wire.
        return !this.isLoading && this.validQueryParameter && this.hasPersonContext && !this.isMockChildSelected
            ? this.category
            : undefined;
    }

    get hasPersonContext() {
        return !this.allowsRepresentation || this.personSelectionConfirmed;
    }

    get representedPersonId() {
        // undefined: no confirmed person context.
        // null: authenticated user.
        // Otherwise: currently a MOCK child value.
        // TODO(representation-api): Use an opaque identifier from the authorized endpoint. Apex must revalidate authorization for every operation.
        if (!this.hasPersonContext) {
            return undefined;
        }

        return this.selectedPersonValue === SELF_PERSON_VALUE || !this.allowsRepresentation
            ? null
            : this.selectedPersonValue;
    }

    get threadQueryType() {
        return this.threadQueryCategory !== undefined ? this.threadTypeToMake : undefined;
    }

    get showPersonSelection() {
        return (
            this.allowsRepresentation &&
            this.representationLoaded &&
            !this.representationLoadFailed &&
            !this.personSelectionConfirmed
        );
    }

    get showRepresentationLoadError() {
        return this.allowsRepresentation && this.representationLoadFailed;
    }

    get selectedPersonLabel() {
        return this.personOptions.find((option) => option.value === this.selectedPersonValue)?.label || '';
    }

    get showSelectedPerson() {
        return this.allowsRepresentation && this.personSelectionConfirmed;
    }

    get isWritingForChild() {
        return this.showSelectedPerson && this.selectedPersonValue !== SELF_PERSON_VALUE;
    }

    get personSelectionInvalid() {
        return Boolean(this.personSelectionError);
    }
}

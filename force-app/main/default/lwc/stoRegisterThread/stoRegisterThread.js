import { LightningElement, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import createThreadWithCase from '@salesforce/apex/stoHelperClass.createThreadWithCase';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';

import welcomelabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
import welcomelabelBTO from '@salesforce/label/c.Beskjed_til_oss_intro_text';
import headline from '@salesforce/label/c.Skriv_til_oss_headline';
import accepterrmessage from '@salesforce/label/c.Skriv_til_oss_headline';
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

const maxThreadCount = 3;
const spinnerReasonTextMap = { send: 'Sender melding. Vennligst vent.', close: 'Avslutter samtale. Vennligst vent.' };
export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    @api title;
    @api threadTypeToMake;
    showspinner = false;
    selectedTheme;
    acceptedcategories = new Set();
    currentPageReference = null;
    urlStateParameters;
    subpath;
    acceptedTerms = false;
    label = {
        welcomelabel,
        welcomelabelBTO,
        headline,
        accepterrmessage,
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
    logopath = navlogos + '/email.svg';
    deletepath = navlogos + '/delete.svg';
    newsList;
    errorList = { title: '', errors: [] };
    message;
    modalOpen = false;
    maxLength = 1000;
    openThreadList;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        getAcceptedThemes({ language: 'no' })
            .then((categoryResults) => {
                let categoryList = new Set();
                categoryResults.forEach((stoCategory) => {
                    categoryList.add(stoCategory.STO_Category__c);
                });
                this.acceptedcategories = categoryList;
            })
            .catch((error) => {
                //Failed getting sto categories
            });
    }

    /**
     * Sets the Selectedtheme based on the URL parameter.
     * @param {} currentPageReference
     * @author Lars Petter Johnsen
     */
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.subpath =
                currentPageReference.attributes.name === 'Beskjed_til_oss__c' ? '/beskjed-til-oss/' : '/skriv-til-oss/';
            this.urlStateParameters = currentPageReference.state;
            this.setParametersBasedOnUrl();
        }
    }
    /**
     * Finds if there are any news based on the selected theme.
     *  @author Lars Petter Johnsen
     */
    @wire(getNews, { category: '$selectedTheme', threadType: '$threadTypeToMake' })
    wirenews(result) {
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.newsList = result.data;
        }
    }

    @wire(getOpenThreads, { category: '$selectedTheme', threadType: '$threadTypeToMake' })
    openThread(wireData) {
        const { error, data } = wireData;
        if (error) {
            console.log(error);
        }
        this._wireThreadData = wireData;
        this.openThreadList = data;
    }

    get validparameter() {
        let valid = this.acceptedcategories.has(this.selectedTheme);
        return valid;
    }

    setParametersBasedOnUrl() {
        this.selectedTheme = this.urlStateParameters.category;
    }

    renderedCallback() {
        if (this.showspinner) {
            let spinner = this.template.querySelector('.spinner');
            spinner.focus();
        }
    }
    /**
     *  Handle Terms Modal Start
     */

    togglechecked() {
        this.acceptedTerms = !this.acceptedTerms;
    }

    get termsModal() {
        return this.template.querySelector('c-community-modal');
    }

    get termsContentText() {
        return this.label.SERVICE_TERMS + this.label.SERVICE_TERMS_2;
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
        const medskriv = this.template.querySelector('c-ds-radio')?.getValue();
        if (
            this.acceptedTerms == true &&
            this.message &&
            this.message.length != null &&
            this.message.length <= this.maxLength &&
            medskriv != null
        ) {
            this.showspinner = true;
            this.spinnerText = spinnerReasonTextMap['send'];

            createThreadWithCase({
                theme: this.selectedTheme,
                msgText: this.message,
                medskriv: medskriv,
                type: this.threadTypeToMake
            }).then((thread) => {
                this.showspinner = false;
                if (this.subpath === '/beskjed-til-oss/') {
                    this.navigateToBTO(thread);
                } else {
                    window.open(
                        (this.linkUrl = basepath + this.subpath + thread.Id + '/' + encodeURIComponent(thread.Name)),
                        '_self'
                    );
                }
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
        this.spinnerText = spinnerReasonTextMap['close'];
        closeThread({ id: selectedThreadId })
            .then(() => {
                refreshApex(this._wireThreadData)
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

    get showOpenThreadWarning() {
        return this.openThreadList !== null && this.openThreadList !== undefined;
    }

    get openThreadText() {
        if (this.openThreadList.length < maxThreadCount) {
            return (
                'Du har allerede åpne samtaler om ' +
                this.selectedTheme.toLowerCase() +
                '. Hvis du lurer på noe mer, kan du <a href="' +
                this.openThreadLink +
                '">fortsette dine åpne samtaler</a>. Du kan ikke ha mer enn 3 åpne samtaler samtidig.'
            );
        }
        return (
            'Du har ' +
            this.openThreadList.length +
            ' åpne samtaler om ' +
            this.selectedTheme.toLowerCase() +
            '. Du kan maksimalt ha 3 åpne samtaler. Hvis du vil opprette en ny samtale, må du derfor avslutte noen av de du allerede har. Du kan også fortsette allerede åpne samtaler ved å klikke på de.'
        );
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
            this.openThreadList === null ||
            this.openThreadList === undefined ||
            this.openThreadList.length < maxThreadCount
        );
    }

    get backdropClass() {
        return this.hideDeleteModal === true ? 'slds-hide' : 'backdrop';
    }

    get introLabel() {
        return this.threadTypeToMake === 'BTO' ? this.label.welcomelabelBTO : this.label.welcomelabel;
    }

    handleCloseThread(e) {
        const selectedThread = this.openThreadList[e.detail];
        if (selectedThread.recordId) {
            this.closeSelectedThread(selectedThread.recordId);
        }
    }
}

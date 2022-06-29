import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import { loadStyle } from 'lightning/platformResourceLoader';
import createRecords from '@salesforce/apex/stoHelperClass.createRequest';
import getAcceptedThemes from '@salesforce/apex/stoHelperClass.getThemes';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import getOpenThreads from '@salesforce/apex/stoHelperClass.getOpenThreads';
import closeThread from '@salesforce/apex/stoHelperClass.closeThread';
import navlogos from '@salesforce/resourceUrl/navsvglogos';

import welcomlabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
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

export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    showspinner = false;
    selectedTheme;
    acceptedcategories = new Set();
    currentPageReference = null;
    urlStateParameters;
    acceptedTerms = false;
    label = {
        welcomlabel,
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
    logopath = navlogos + '/email.svg';
    deletepath = navlogos + '/delete.svg';
    newslist;
    errorList = { title: '', errors: [] };
    message;
    modalOpen = false;
    maxLength = 1000;
    openThreadList;
    hideDeleteModal = true;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        console.log('geir');
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
            this.urlStateParameters = currentPageReference.state;
            this.setParametersBasedOnUrl();
        }
    }
    /**
     * Finds if there are any news based on the selected theme.
     *  @author Lars Petter Johnsen
     */
    @wire(getNews, { category: '$selectedTheme' })
    wirenes(result) {
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.newslist = result.data;
        }
    }

    @wire(getOpenThreads, { category: '$selectedTheme' })
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
        loadStyle(this, dekoratoren);
        if (this.showspinner) {
            let spinner = this.template.querySelector('.spinner');
            spinner.focus();
        }
        console.log(this.validparameter);
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

    /**
     * Creates a Thread record, with an message attached, and then navigates the user to the record page
     * @Author Lars Petter Johnsen
     */
    submitrequest() {
        if (
            this.acceptedTerms == true &&
            this.message &&
            this.message.length != null &&
            this.message.length <= this.maxLength
        ) {
            this.showspinner = true;

            createRecords({ theme: this.selectedTheme, msgText: this.message }).then((thread) => {
                this.showspinner = false;
                window.open(
                    (this.linkUrl = basepath + '/skriv-til-oss/' + thread.Id + '/' + encodeURIComponent(thread.Name)),
                    '_self'
                );
            });
        } else {
            this.errorList = { title: '', errors: [] };
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
                    Text: 'Du må godta vilkårene for å sende beskjeden.'
                });
            }
            let errorSummary = this.template.querySelector('.errorSummary');
            errorSummary.focusHeader();
        }
    }

    shaggy(event) {
        console.log('geir');
        const t = event.currentTarget.dataset.id;
        this.showspinner = true;
        console.log(t);
        closeThread({ id: t })
            .then(() => {
                console.log('Kidney');
                refreshApex(this._wireThreadData)
                    .then((a) => {
                        console.log('a');
                        console.log(a);
                        this.showspinner = false;
                    })
                    .catch((e) => {
                        console.log('e');
                        console.log(e);
                    });
            })
            .catch((e) => {
                console.log('g');
                console.log(e);
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
        } else if (event.keyCode === 9 || event.code === 'Tab') {
            const el = event.path[0];
            if (el.classList.contains('firstfocusable')) {
                this.template.querySelector('.lastFocusElement').focus();
            } else if (el.classList.contains('lastfocusable')) {
                this.termsModal.focusLoop();
            }
        }
    }

    get showOpenThreadWarning() {
        return this.openThreadList !== null && this.openThreadList !== undefined;
    }

    get openThreadText() {
        if (this.openThreadList.length < 5) {
            return (
                'Du har allerede en åpen samtale om ' +
                this.selectedTheme.toLowerCase() +
                '. Hvis du lurer på noe mer, kan du <a href="' +
                this.openThreadLink +
                '">fortsette samtalen</a>.'
            );
        }
        return 'Du har 5 åpne samtaler på dette temaet. <br/> Hvis du vil opprette en ny samtale, så må du lukke en av de du allerede har.';
    }

    get openThreadLink() {
        return basepath + '/skriv-til-oss/' + this.openThreadList[0].Id;
    }

    get alertType() {
        return this.openThreadList.length >= 5 ? 'advarsel' : 'info';
    }

    get showTextArea() {
        console.log(this.openThreadList);
        return this.openThreadList === null || this.openThreadList === undefined || this.openThreadList.length < 5;
    }

    get mby() {
        return false;
    }

    testington(e) {
        e.preventDefault();
        console.log('testington');
        this.hideDeleteModal = false;
    }

    get backdropClass() {
        return this.hideDeleteModal === true ? 'slds-hide' : 'backdrop';
    }

    get modalClass() {
        return 'slds-modal slds-show uiPanel north' + (this.hideDeleteModal === true ? ' geir' : ' slds-fade-in-open');
    }

    closeModal() {
        this.hideDeleteModal = true;
        const btn = this.template.querySelector('.endDialogBtn');
        btn.focus();
    }

    trapFocusStart() {
        const firstElement = this.template.querySelector('.closeButton');
        firstElement.focus();
    }

    confirmCloseThread(e) {
        console.log('Bø');
    }

    trapFocusEnd() {
        const lastElement = this.template.querySelector('.cancelButton');
        lastElement.focus();
    }
}

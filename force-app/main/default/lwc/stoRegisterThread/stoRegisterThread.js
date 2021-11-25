import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import { loadStyle } from 'lightning/platformResourceLoader';
import createRecords from '@salesforce/apex/stoHelperClass.createRequest';
import getNews from '@salesforce/apex/stoHelperClass.getCategoryNews';
import navlogos from '@salesforce/resourceUrl/navsvglogos';

import welcomlabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
import headline from '@salesforce/label/c.Skriv_til_oss_headline';
import accepterrmessage from '@salesforce/label/c.Skriv_til_oss_headline';
import acceptermtext from '@salesforce/label/c.Skriv_til_oss_Accept_terms_text';
import showtermstext from '@salesforce/label/c.Skriv_til_oss_Show_terms';
import textareadescription from '@salesforce/label/c.Skriv_til_oss_text_area_description';
import SERVICE_TERMS_HEADER from '@salesforce/label/c.STO_Skriv_til_oss_terms_header';
import SERVICE_TERMS from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text';
import ACCEPT_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Accept_Terms_Button';
import ACCEPT_TERMS_ERROR from '@salesforce/label/c.Skriv_til_oss_Accept_terms_error_message';
import DENY_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Deny_Terms_Button';
import EMPTY_TEXT_FIELD_ERROR from '@salesforce/label/c.STO_Skriv_til_oss_text_field_empty_error';
import INCORRECT_CATEGORY from '@salesforce/label/c.STO_Incorrect_Category';

import dist from '@salesforce/resourceUrl/dist';
export default class StoRegisterThread extends NavigationMixin(LightningElement) {
    validparameter;
    showspinner = false;
    acceptedcategories = [
        'Arbeid',
        'Helse',
        'Familie',
        'Ufør',
        'Pensjon',
        'Internasjonal',
        'Øvrig',
        'Bil',
        'Hjelpemidler'
    ];
    currentPageReference = null;
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
        ACCEPT_TERMS_BUTTON,
        ACCEPT_TERMS_ERROR,
        DENY_TERMS_BUTTON,
        EMPTY_TEXT_FIELD_ERROR,
        INCORRECT_CATEGORY
    };
    logopath = navlogos + '/email.svg';
    newslist;

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
    setParametersBasedOnUrl() {
        if (this.acceptedcategories.includes(this.urlStateParameters.category)) {
            this.selectedTheme = this.urlStateParameters.category;
            this.validparameter = true;
        } else {
            try {
                console.log(window.location);
                //  window.location.replace("https://www.google.no/404");
            } catch (e) {
                console.log(e);
            }
        }
    }

    @track message;
    inputChange(event) {
        this.message = event.target.value;

        if (this.message && this.message.length != 0) {
            this.showErrorNoMessage = false;
        }
    }

    renderedCallback() {
        loadStyle(this, dekoratoren);
        loadStyle(this, dist);
        if (this.showspinner) {
            let spinner = this.template.querySelector('.spinner');
            spinner.focus();
        }
    }
    /**
     *  Handle Terms Modal Start
     */

    togglechecked() {
        this.acceptedTerms = this.acceptedTerms == true ? false : true;
        if (this.showError == true) {
            this.showError = false;
        }
    }

    get termsModal() {
        return this.template.querySelector('c-community-modal');
    }

    showTerms() {
        const modal = this.template.querySelector('c-community-modal');
        this.termsModal.showModal = true;
    }

    closeTerms() {
        const modal = this.template.querySelector('c-community-modal');
        this.termsModal.showModal = false;
    }

    termsAccepted() {
        this.acceptedTerms = true;
        this.closeTerms();
    }

    termsDenied() {
        this.acceptedTerms = false;
        this.closeTerms();
    }
    /**
     * Handles terms modal end
     */

    /**
     * Creates a Thread record, with an message attached, and then navigates the user to the record page
     * @Author Lars Petter Johnsen
     */
    submitrequest() {
        if (this.acceptedTerms == true && this.message && this.message.length != null) {
            this.showspinner = true;

            createRecords({ theme: this.selectedTheme, msgText: this.message }).then((result) => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Thread__c',
                        actionName: 'view'
                    }
                });
            });
        } else {
            if (this.acceptedTerms == false) {
                this.showError = true;
            }
            if (this.message == null || !this.message || this.message.length != 0) {
                this.showErrorNoMessage = true;
            }
        }
    }
}

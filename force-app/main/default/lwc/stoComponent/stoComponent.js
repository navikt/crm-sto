import { LightningElement, wire, track, api } from 'lwc';
import getThemes from '@salesforce/apex/stoHelperClass.getThemes';
import createRecords from '@salesforce/apex/stoHelperClass.createRequest';
import { NavigationMixin } from 'lightning/navigation';
import logos from '@salesforce/resourceUrl/navsvglogos';
import dekoratoren from '@salesforce/resourceUrl/dekoratoren';
import { loadStyle } from 'lightning/platformResourceLoader';
import locale from '@salesforce/i18n/lang';

import welcomlabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
import headline from '@salesforce/label/c.Skriv_til_oss_headline';
import accepterrmessage from '@salesforce/label/c.Skriv_til_oss_headline';
import acceptermtext from '@salesforce/label/c.Skriv_til_oss_Accept_terms_text';
import showtermstext from '@salesforce/label/c.Skriv_til_oss_Show_terms';
import textareadescription from '@salesforce/label/c.Skriv_til_oss_text_area_description';
import SERVICE_TERMS from '@salesforce/label/c.STO_Skriv_til_oss_terms_og_use_text';
import ACCEPT_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Accept_Terms_Button';
import DENY_TERMS_BUTTON from '@salesforce/label/c.STO_Skriv_til_oss_Deny_Terms_Button';

export default class StoComponent extends NavigationMixin(LightningElement) {
    fillform = logos + '/FillForms.svg';

    //Picklist setup
    selectedLanguage = 'Norwegian';
    errormessage = 'Tekstfeltet er tomt';
    termsdescriptor = 'Jeg godtar vilkårene for bruk av tjenesten.';
    showtermsdescriptor = 'Vis vilkår';
    approvetermstext = 'Du må godta vilkårene for å sende beskjeden';
    welcometext = 'Send bare beskjeder som kan ha betydning for saken din. Husk å få med alle relevante opplysninger.';

    @track norwegiandescriptior = 'Norsk (Bokmål)';
    @track englishdescriptior = 'English';

    @track languages = [
        { name: 'Norwegian', label: this.norwegiandescriptior, selected: true },
        { name: 'English', label: this.englishdescriptior, selected: false }
    ];

    selectMultiple = false;
    selectRequired = false;
    selectDisabled = false;
    localed = locale;
    themes = [];
    selectedTheme;
    acceptedTerms = false;
    shownewmessage = false;
    showerror = false;
    showerrornomessage = false;
    newrecord;
    showTermsModal = false;

    label = {
        welcomlabel,
        headline,
        accepterrmessage,
        acceptermtext,
        showtermstext,
        textareadescription,
        SERVICE_TERMS,
        ACCEPT_TERMS_BUTTON,
        DENY_TERMS_BUTTON
    };
    renderedCallback() {
        loadStyle(this, dekoratoren);
    }

    //Changes to language
    handlePicklist(event) {
        this.selectedLanguage = event.detail;
        this.switchlanguage(event);
    }
    //TODO - There has to be a more elegant solution for this?
    switchlanguage(event) {
        if (event.detail == 'Norwegian') {
            this.errormessage = 'Tekstfeltet er tomt';
            this.termsdescriptor = 'Jeg godtar vilkårene for bruk av tjenesten.';
            this.showtermsdescriptor = 'Vis vilkår';
            this.approvetermstext = 'Du må godta vilkårene for å sende beskjeden';
            this.welcometext =
                'Send bare beskjeder som kan ha betydning for saken din. Husk å få med alle relevante opplysninger.';
        } else if (event.detail == 'English') {
            this.errormessage = 'Textarea is empty';
            this.termsdescriptor = 'I Accept the terms and conditions.';
            this.showtermsdescriptor = 'Show terms';
            this.approvetermstext = 'You have to accept the terms in order to send this message';
            this.welcometext = 'Only send information relevant to your case';
        }
    }

    @track message;
    nameChange(event) {
        this.message = event.target.value;
    }

    handleselectedtheme(event) {
        this.selectedTheme = event.detail;
        this.shownewmessage = true;
    }
    togglechecked() {
        this.acceptedTerms = this.acceptedTerms == true ? false : true;
        if (this.showerror == true) {
            this.showerror = false;
        }
    }
    @wire(getThemes, { language: '$localed' })
    wirethemes(result) {
        console.log(result);
        if (result.error) {
            console.log(result.error);
        } else if (result.data) {
            this.themes = result.data;
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

    submitrequest() {
        if (this.acceptedTerms == true && this.message != null) {
            createRecords({ theme: this.selectedTheme.Label, msgText: this.message }).then((result) => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Thread__c',
                        actionName: 'view'
                    }
                });
            });
        } else if (this.acceptedTerms == false) {
            this.showerror = true;
        } else if (this.message == null) {
            this.showerrornomessage = true;
        }
    }
}

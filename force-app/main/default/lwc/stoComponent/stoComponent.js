import { LightningElement, wire, track } from 'lwc';
import getThemes from '@salesforce/apex/stoHelperClass.getThemes';
import createRecords from '@salesforce/apex/stoHelperClass.createRequest';
import { NavigationMixin } from 'lightning/navigation';
import logos from '@salesforce/resourceUrl/stoLogos';

import welcomlabel from '@salesforce/label/c.Skriv_til_oss_intro_text';
import headline from '@salesforce/label/c.Skriv_til_oss_headline';
export default class StoComponent extends NavigationMixin(LightningElement) {
    fillform = logos + '/FillForms.svg';
    dialog = navlogos + '/dialog.svg'
    themes = [];
    selectedTheme;
    accepterterms = false;
    shownewmessage = false;
    showerror = false;
    showerrornomessage = false;
    newrecord;
    label = {
        welcomlabel, headline
    };

    @track message;
    nameChange(event) {
        this.message = event.target.value;
    }
    handleselectedtheme(event) {
        this.selectedTheme = event.detail;
        this.shownewmessage = true;
    }
    togglechecked() {
        this.accepterterms = this.accepterterms == true ? false : true;
        if (this.showerror == true) {
            this.showerror = false;
        }
    }
    @wire(getThemes, {})
    wirethemes(result) {

        if (result.error) {
            console.log(result.error);
        }
        else if (result.data) {
            this.themes = result.data;
        }
    }

    submitrequest() {
        console.log(this.accepterterms);
        if (this.accepterterms == true && this.message != null) {
            createRecords({ theme: this.selectedTheme.Label, msgText: this.message })
                .then(result => {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result,
                            objectApiName: 'Thread__c',
                            actionName: 'view'
                        },
                    });
                });
        }
        else if (this.accepterterms == false) {
            this.showerror = true;
        }
        else if (this.message == null) {
            this.showerrornomessage = true;
        }

    }
}
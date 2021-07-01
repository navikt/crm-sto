import { LightningElement, track } from 'lwc';
import setLanguage from '@salesforce/apex/CommunityLanguageSelectorUtility.setLanguage';
import getLanguage from '@salesforce/apex/CommunityLanguageSelectorUtility.getLanguage';
//import experiencelang from '@salesforce/community/language';
import locale from '@salesforce/i18n/lang';

export default class CommunityLanguageSelector extends LightningElement {

    @track clickhere = 'Velg Språk';
    @track norwegiandescriptior = 'Norsk (Bokmål)';
    @track englishdescriptior = 'English';
    @track languages = [
        { name: 'Velg Språk', label: this.clickhere, selected: true },
        { name: 'Norwegian', label: this.norwegiandescriptior, selected: false },
        { name: 'English', label: this.englishdescriptior, selected: false }
    ]

    handlePicklist(event) {
        if (event.detail != 'Velg Språk') {
            setLanguage({ language: event.detail })
                .then((result) => {
                    console.log(result);
                    location.reload()
                })
        }
    }

}
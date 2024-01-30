import { LightningElement, track } from 'lwc';
import setLanguage from '@salesforce/apex/CommunityLanguageSelectorUtility.setLanguage';
//import getLanguage from '@salesforce/apex/CommunityLanguageSelectorUtility.getLanguage';
//import experiencelang from '@salesforce/community/language';
//import locale from '@salesforce/i18n/lang';

import LANGUAGE_PLACEHOLDER from '@salesforce/label/c.Community_Language_Selector_Placeholder';
import LANGUAGE_NORWEGIAN_NB from '@salesforce/label/c.Community_Language_Selector_Norwegian';
import LANGUAGE_ENGLISH from '@salesforce/label/c.Community_Language_Selector_English';

export default class CommunityLanguageSelector extends LightningElement {
    @track languages = [
        { name: 'PLACEHOLDER', label: LANGUAGE_PLACEHOLDER, selected: true },
        { name: 'Norwegian', label: LANGUAGE_NORWEGIAN_NB, selected: false },
        { name: 'English', label: LANGUAGE_ENGLISH, selected: false }
    ];

    handlePicklist(event) {
        if (event.detail !== 'PLACEHOLDER') {
            setLanguage({ language: event.detail }).then((result) => {
                console.log(result);
                window.location.reload();
            });
        }
    }
}

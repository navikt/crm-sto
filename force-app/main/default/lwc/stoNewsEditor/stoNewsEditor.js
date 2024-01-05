import { LightningElement, wire } from 'lwc';
import getAllNews from '@salesforce/apex/stoNewsController.getAllNews';
import updateNews from '@salesforce/apex/stoNewsController.updateNews';
import { refreshApex } from '@salesforce/apex';

export default class StoNewsEditor extends LightningElement {
    allNews;
    _selectedNews;
    _wiredNews;

    @wire(getAllNews)
    wiredData(apexData) {
        this._wiredNews = apexData;
        const { error, data } = apexData;
        console.log('Data whee', JSON.stringify(data));
        if (data) {
            this.allNews = data;
            if (this.selectedNews) {
                this.selectedNews = this.selectedNews.Id;
            }
        } else if (error) {
            console.error('Error:', error);
        }
    }

    get loopNews() {
        return this.allNews != null
            ? Object.keys(this.allNews).map((news) => ({ category: news, news: this.allNews[news] }))
            : null;
    }

    get availableCategories() {
        return Object.keys(this.allNews);
    }

    handleClick(event) {
        if (this.selectedNews) {
            const abber = this.template.querySelector("[data-target-id='" + this.selectedNews.Id + "']");
            abber.classList.remove('highlight');
        }

        const id = event.target.dataset.id;
        this.selectedNews = id;

        const abba = this.template.querySelector("[data-target-id='" + id + "']");
        abba.classList.add('highlight');
        this.resetChanges();
    }

    saveSelectedThing() {
        const content = this.template.querySelector("[data-id='body']")?.value;
        const title = this.template.querySelector("[data-id='title']")?.value;
        const enabledSTO = this.template.querySelector("[data-id='enabledSTO']")?.checked;
        const enabledBTO = this.template.querySelector("[data-id='enabledBTO']")?.checked;
        updateNews({
            content: content,
            title: title,
            category: this.selectedNews.STO_Category__c,
            developerName: this.selectedNews.DeveloperName,
            enabledSTO: enabledSTO,
            enabledBTO: enabledBTO
        })
            .then(() => {
                console.log('Nicty');
            })
            .catch(() => {
                console.log('Not nicty');
            });
    }

    resetChanges() {
        console.log(this.selectedNews);
        const content = this.template.querySelector("[data-id='body']");
        const title = this.template.querySelector("[data-id='title']");
        const enabledSTO = this.template.querySelector("[data-id='enabledSTO']");
        const enabledBTO = this.template.querySelector("[data-id='enabledBTO']");
        content.value = this.selectedNews.STO_Body__c;
        title.value = this.selectedNews.STO_Header__c;
        enabledSTO.checked = this.selectedNews.Enabled_STO__c;
        enabledBTO.checked = this.selectedNews.Enabled_BTO__c;
    }

    refreshNews() {
        refreshApex(this._wiredNews);
    }

    get selectedNews() {
        return this._selectedNews;
    }

    set selectedNews(id) {
        let match;
        for (const news of Object.values(this.allNews)) {
            for (const a of news) {
                if (a.Id === id) {
                    match = a;
                    break;
                }
            }
            if (match) break;
        }
        this._selectedNews = match;
    }
}

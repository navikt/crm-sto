import { LightningElement, wire } from 'lwc';
import getAllNews from '@salesforce/apex/stoNewsController.getAllNews';
import updateNews from '@salesforce/apex/stoNewsController.updateNews';

export default class StoNewsEditor extends LightningElement {
    allNews;
    selectedNews;

    @wire(getAllNews)
    wiredData({ error, data }) {
        if (data) {
            console.log('Data', data);
            this.allNews = data;
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
        this.selectedNews = match;

        const abba = this.template.querySelector("[data-target-id='" + id + "']");
        abba.classList.add('highlight');
    }

    saveSelectedThing() {
        console.log('Me is you');
        const content = this.template.querySelector("[data-id='body']")?.value;
        const title = this.template.querySelector("[data-id='title']")?.value;
        updateNews({
            content: content,
            title: title,
            category: this.selectedNews.STO_Category__c,
            developerName: this.selectedNews.DeveloperName
        })
            .then(() => {
                console.log('Nicty');
            })
            .catch(() => {
                console.log('Not nicty');
            });
    }

    resetChanges() {
        const content = this.template.querySelector("[data-id='body']");
        const title = this.template.querySelector("[data-id='title']");
        content.value = this.selectedNews.STO_Body__c;
        title.value = this.selectedNews.STO_Header__c;
    }
}

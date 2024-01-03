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
        console.log('Blonk');
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
    }

    saveSelectedThing() {
        console.log('Me is you');
        const content = this.template.querySelector("[data-id='body']")?.value;
        const title = this.template.querySelector("[data-id='title']")?.value;
        // console.log(content);
        // console.log(title);
        // console.log(this.selectedNews.STO_Category__c);
        // console.log(this.selectedNews.DeveloperName);
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
}

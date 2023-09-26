import { LightningElement, wire} from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import Amplitude from '@salesforce/resourceUrl/Amplitude';

import { MessageContext, subscribe, unsubscribe, APPLICATION_SCOPE } from 'lightning/messageService';
import tabCreatedChannel from '@salesforce/messageChannel/lightning__tabCreated';
import tabFocusedChannel from '@salesforce/messageChannel/lightning__tabFocused';
import tabClosedChannel from "@salesforce/messageChannel/lightning__tabClosed";

import { getTabInfo } from 'lightning/platformWorkspaceApi';

import Id from "@salesforce/user/Id";

export default class NksAmplitude extends LightningElement {
    static renderMode = 'light';

    @wire(MessageContext) messageContext;

   tabCreatedSubscription = null;
   tabFocusedSubscription = null;
   tabClosedSubscription  = null;

    connectedCallback() {
        console.log('utility bar');
        loadScript(this, Amplitude + '/Amplitude.js').then(() => {
            window.amplitude.init('0daf26baf4c01a4d9eda01d53669d001', '', {
                apiEndpoint: 'amplitude.nav.no/collect',
                serverZone: 'EU',
                saveEvents: false,
                includeUtm: true,
                batchEvents: false,
                includeReferrer: true
            });
            console.log('amplitude');
            console.log(JSON.stringify(amplitude));
            window.amplitude.track('Hello World From Utility Bar!');

            this.subscribeToMessageChannel();
            console.log('subscribed');

        });
    }
    disconnectedCallback() {
        this.unsubscribe();
     }
    
     subscribeToMessageChannel() {
        if (!this.tabCreatedSubscription) {
            this.tabCreatedSubscription = subscribe(
                this.messageContext,
                tabCreatedChannel,
                (message) => this.handleMessage(message,'created'),
                { scope: APPLICATION_SCOPE }
            );
        }
        if (!this.tabFocusedSubscription) {
            this.tabFocusedSubscription = subscribe(
                this.messageContext,
                tabFocusedChannel,
                (message) => this.handleMessage(message,'focused'),
                { scope: APPLICATION_SCOPE }
            );
        }
        if (!this.tabClosedSubscription) {
            this.tabClosedSubscription = subscribe(
                this.messageContext,
                tabClosedChannel,
                (message) => this.handleMessage(message,'closed'),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

     unsubscribe() {
        if (this.tabCreatedSubscription) {
            unsubscribe(this.tabCreatedSubscription);
            this.tabCreatedSubscription = null;
        }
        if (this.tabFocusedSubscription) {
            unsubscribe(this.tabFocusedSubscription);
            this.tabFocusedSubscription = null;
        }
        if (this.tabClosedSubscription) {
            unsubscribe(this.tabClosedSubscription);
            this.tabClosedSubscription = null;
        }
     }
     
     handleMessage(message,type) {
        console.log('message');
        console.log(JSON.stringify(message));

        let properties = { 
            ...message,
            'userId' : Id,
            'type' : type,
            'timestamp' : new Date().toJSON()
        };

        console.log(JSON.stringify(properties));

        let tabId1;
        let tabId2;
        switch (type) {
            case 'focused':
                tabId1 = message.currentTabId;
                tabId2 = message.previousTabId ? message.previousTabId : null; 
                break;
            case 'created':
                tabId1 = message.tabId;
                break;
            case 'closed':
                tabId1 = message.tabId;
                break;
            default:
                break;
        }



        Promise.all([
            ... (tabId1) ? [getTabInfo(tabId1)] : [],
            ... (tabId2) ? [getTabInfo(tabId2)] : []
        ]).then(
            (values) => {
               let  info = {
                    ...properties, 
                    'tabInfo' : values
                }
                console.log(JSON.stringify(info));
                window.amplitude.track('tabEvent', info);
            }
        ).catch((error) => console.log(error));

     }
}

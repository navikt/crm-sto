import { LightningElement, api } from 'lwc';

export default class CommunityExpandablePanel extends LightningElement {
    showpanel = false;
    @api header;
    @api body;

    togglevisible() {
        console.log(this.showpanel);
        this.showpanel = !this.showpanel;
    }

    get lenkepanelClasses() {
        return 'lenkepanel hoved-panel' + (this.showpanel ? ' hoved-panel--aktiv' : '');
    }
}

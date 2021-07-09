import { LightningElement, api } from 'lwc';

export default class CommunityModal extends LightningElement {
    @api showModal = false;

    closeModal() {
        this.showModal = false;
    }
}

import { LightningElement, api } from 'lwc';

export default class StoInboxCloseItem extends LightningElement {
    @api thread;
    @api index;

    handleClick() {
        this.refs.childRef.openModal();
    }

    handleCloseThread() {
        this.dispatchEvent(
            new CustomEvent('closethread', {
                detail: this.index
            })
        );
    }
}

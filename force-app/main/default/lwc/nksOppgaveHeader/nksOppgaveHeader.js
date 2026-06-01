import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const STATUS_LABELS = {
    AVSLUTTET: 'Ferdigstilt',
    OPPRETTET: 'Åpen',
    AAPEN: 'Åpen',
    AAPNET: 'Åpen',
    UNDER_BEHANDLING: 'Under behandling',
    FERDIGSTILT: 'Ferdigstilt',
    FEILREGISTRERT: 'Feilregistrert'
};

const STATUS_THEME = {
    AVSLUTTET: 'slds-badge slds-theme_success',
    OPPRETTET: 'slds-badge slds-badge_lightest',
    AAPEN: 'slds-badge slds-theme_info',
    AAPNET: 'slds-badge slds-theme_info',
    UNDER_BEHANDLING: 'slds-badge slds-theme_warning',
    FERDIGSTILT: 'slds-badge slds-theme_success',
    FEILREGISTRERT: 'slds-badge slds-theme_error'
};

export default class NksOppgaveHeader extends NavigationMixin(LightningElement) {
    @api status;
    @api isLoading = false;
    @api isSaving = false;
    @api errorMessage;
    @api personName;
    @api personDateOfBirth;
    @api personAccountId;

    get formattedDateOfBirth() {
        if (!this.personDateOfBirth) return null;
        const [year, month, day] = this.personDateOfBirth.split('-');
        return `${day}.${month}.${year}`;
    }

    get statusLabel() {
        return STATUS_LABELS[this.status] ?? this.status;
    }

    get statusClass() {
        return STATUS_THEME[this.status] ?? 'slds-badge slds-badge_lightest';
    }

    get isFinished() {
        return this.status === 'FERDIGSTILT';
    }

    get errorText() {
        if (!this.errorMessage) return null;
        const msg = this.errorMessage.errorMessage ?? 'Ukjent feil';
        const base = `Ferdigstilling av oppgave feilet med feilmelding: ${msg}`;
        if (this.errorMessage.isRetry) {
            return `${base}\nEn utvikler har fått beskjed og vil feilsøke dette.\nOppgaven vil bli automatisk rekjørt på et senere tidspunkt.`;
        }
        return base;
    }

    get isButtonDisabled() {
        return this.isSaving || this.isFinished;
    }

    handleFinishOppgave() {
        this.dispatchEvent(new CustomEvent('finishoppgave'));
    }

    navigateToPersonAccount() {
        if (!this.personAccountId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.personAccountId,
                actionName: 'view'
            }
        });
    }

    handleCopy(event) {
        const hiddenInput = document.createElement('input');
        const eventValue = event.currentTarget.value;
        hiddenInput.value = eventValue;
        document.body.appendChild(hiddenInput);
        hiddenInput.focus();
        hiddenInput.select();
        try {
            // eslint-disable-next-line @locker/locker/distorted-document-exec-command
            document.execCommand('copy');
        } catch (err) {
            console.error('Copy failed', err);
        }
        document.body.removeChild(hiddenInput);
        event.currentTarget.focus();
    }
}

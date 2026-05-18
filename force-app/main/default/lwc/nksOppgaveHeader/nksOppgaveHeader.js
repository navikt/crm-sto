import { LightningElement, api } from 'lwc';

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

export default class NksOppgaveHeader extends LightningElement {
    @api status;
    @api isLoading = false;
    @api isSaving = false;
    @api errorMessage;

    get statusLabel() {
        console.log('status', this.status);
        console.log('statusLabel', STATUS_LABELS[this.status]);
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
}

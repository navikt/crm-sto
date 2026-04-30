import { LightningElement, api } from 'lwc';
import getOppgaveById from '@salesforce/apex/OppgaveManager.getOppgaveById';
import patchEditTaskFromLwc from '@salesforce/apex/OppgaveManager.patchEditTaskFromLwc';

export default class NksOppgavePage extends LightningElement {
    @api oppgaveId;

    oppgave;
    isLoading = false;
    isSaving = false;
    formErrorMessage;
    headerErrorMessage;

    connectedCallback() {
        if (this.oppgaveId) {
            this.loadOppgave();
        }
    }

    async loadOppgave() {
        this.isLoading = true;
        try {
            this.oppgave = await getOppgaveById({ oppgaveId: this.oppgaveId });
        } catch (error) {
            console.error('loadOppgave error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave(event) {
        const updatedFields = event.detail;
        await this.patch({ ...updatedFields, status: this.oppgave.status }, 'form');
    }

    async handleFinishOppgave() {
        this.isSaving = true;
        try {
            const request = {
                id: this.oppgave.id,
                versjon: this.oppgave.versjon,
                status: 'FERDIGSTILT'
            };
            const response = await patchEditTaskFromLwc({ requestJson: JSON.stringify(request) });
            if (response?.isSuccess) {
                this.oppgave = { ...this.oppgave, status: 'FERDIGSTILT', versjon: response.versjon };
                this.headerErrorMessage = null;
            } else {
                this.headerErrorMessage = { errorMessage: response?.errorMessage, isRetry: response?.isRetry };
            }
        } catch (error) {
            this.headerErrorMessage = {
                errorMessage: error?.body?.message ?? error?.message ?? 'Ukjent feil',
                isRetry: false
            };
        } finally {
            this.isSaving = false;
        }
    }

    async patch(fields, errorTarget) {
        this.isSaving = true;
        try {
            // Map from OppgaveV2 structure to flat Oppgave (V1) request
            const request = {
                id: this.oppgave.id,
                versjon: this.oppgave.versjon,
                prioritet: (fields.prioritet ?? this.oppgave.prioritet)?.replace('NORMAL', 'NORM'),
                kommentarTekst: fields.kommentar,
                tema: fields.tema ?? this.oppgave.kategorisering?.tema?.kode,
                oppgavetype: fields.oppgavetype ?? this.oppgave.kategorisering?.oppgavetype?.kode,
                behandlingstema: fields.behandlingstema ?? this.oppgave.kategorisering?.behandlingstema?.kode,
                behandlingstype: fields.behandlingstype ?? this.oppgave.kategorisering?.behandlingstype?.kode,
                tildeltEnhetsnr: fields.tildeltEnhetsnr ?? this.oppgave.fordeling?.enhet?.nr,
                tilordnetRessurs: fields.tilordnetRessurs ?? this.oppgave.fordeling?.medarbeider?.navident,
                fristFerdigstillelse: fields.fristDato ?? this.oppgave.fristDato
            };
            const response = await patchEditTaskFromLwc({ requestJson: JSON.stringify(request) });
            if (response?.isSuccess) {
                await this.loadOppgave();
                this.formErrorMessage = null;
                this.headerErrorMessage = null;
            } else {
                const errorMessage = { errorMessage: response?.errorMessage, isRetry: response?.isRetry };
                if (errorTarget === 'form') {
                    this.formErrorMessage = errorMessage;
                } else {
                    this.headerErrorMessage = errorMessage;
                }
                console.error('patch feilet:', response?.errorMessage);
            }
        } catch (error) {
            const errorMessage = {
                errorMessage: error?.body?.message ?? error?.message ?? 'Ukjent feil',
                isRetry: false
            };
            if (errorTarget === 'form') {
                this.formErrorMessage = errorMessage;
            } else {
                this.headerErrorMessage = errorMessage;
            }
            console.error('patch feilet:', error);
        } finally {
            this.isSaving = false;
        }
    }

    get hasExternalReference() {
        return !!this.oppgave?.utvidelser?.henvendelseId;
    }
}

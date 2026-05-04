import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import OPPGAVE_CREATED_CHANNEL from '@salesforce/messageChannel/oppgaveCreated__c';
import USER_ID from '@salesforce/user/Id';
import USER_NAV_IDENT_FIELD from '@salesforce/schema/User.CRM_NAV_Ident__c';
import getAllAssignedOpenOppgaver from '@salesforce/apex/OppgaveManager.getAllAssignedOpenOppgaver';
import getPersonInfo from '@salesforce/apex/OppgaveManager.getPersonInfo';
import getCodeToNameMap from '@salesforce/apex/stoHelperClass.getCodeToNameMap';

const DATE_FORMAT = { day: '2-digit', month: '2-digit', year: 'numeric' };

export default class NksOppgaveListHome extends NavigationMixin(LightningElement) {
    oppgaver = [];
    personData = {};
    codeToNameMap = {};
    isRefreshDisabled = false;
    isLoading = false;
    navIdent;
    oppgaveCreatedSubscription;

    @wire(MessageContext) messageContext;

    @wire(getCodeToNameMap)
    wiredCodeToNameMap({ data, error }) {
        if (data) this.codeToNameMap = data;
        else if (error) console.error('Error fetching code to name map:', error);
    }

    @wire(getRecord, { recordId: USER_ID, fields: [USER_NAV_IDENT_FIELD] })
    wiredUser({ data, error }) {
        if (data) {
            this.navIdent = getFieldValue(data, USER_NAV_IDENT_FIELD) ?? this.navIdent;
            this.loadOppgaver();
        } else if (error) {
            console.error('Error fetching user:', error);
        }
    }

    connectedCallback() {
        this.subscribeToOppgaveCreated();
    }

    disconnectedCallback() {
        if (this.oppgaveCreatedSubscription) {
            unsubscribe(this.oppgaveCreatedSubscription);
            this.oppgaveCreatedSubscription = null;
        }
    }

    subscribeToOppgaveCreated() {
        if (this.oppgaveCreatedSubscription) return;
        this.oppgaveCreatedSubscription = subscribe(
            this.messageContext,
            OPPGAVE_CREATED_CHANNEL,
            () => {
                this.loadOppgaver();
            },
            { scope: APPLICATION_SCOPE }
        );
    }

    async loadOppgaver() {
        if (!this.navIdent) return;
        this.isLoading = true;
        try {
            this.oppgaver = ((await getAllAssignedOpenOppgaver({ navIdent: this.navIdent })) ?? [])
                .filter((oppgave) => oppgave.id != null)
                .sort((a, b) => {
                    if (!a.fristFerdigstillelse) return 1;
                    if (!b.fristFerdigstillelse) return -1;
                    return new Date(a.fristFerdigstillelse) - new Date(b.fristFerdigstillelse);
                })
                .slice(0, 10)
                .map((oppgave) => ({
                    ...oppgave,
                    fristFormatted: oppgave.fristFerdigstillelse
                        ? new Date(oppgave.fristFerdigstillelse).toLocaleDateString('nb-NO', DATE_FORMAT)
                        : '',
                    tema: this.codeToNameMap[oppgave.tema] ?? oppgave.tema,
                    oppgavetype: this.codeToNameMap[oppgave.oppgavetype] ?? oppgave.oppgavetype,
                    brukerIdent:
                        oppgave.bruker?.type === 'PERSON' ? oppgave.bruker.ident : (oppgave.personIdent ?? null)
                }));

            const personIdents = [...new Set(this.oppgaver.map((t) => t.brukerIdent).filter(Boolean))];
            this.personData = await getPersonInfo({ personIdents });
        } catch (error) {
            console.error('Error fetching oppgaver:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        if (this.isLoading || this.isRefreshDisabled) return;
        this.isRefreshDisabled = true;

        this.loadOppgaver();

        setTimeout(() => {
            // 10 sec delay to avoid spamming requests
            this.isRefreshDisabled = false;
        }, 10000);
    }

    handleNavigateToOppgave(event) {
        const oppgaveId = event.currentTarget.dataset.id;
        const oppgavetype = event.currentTarget.dataset.oppgavetype;
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__crmOppgaveNavigation'
            },
            state: {
                c__oppgaveId: oppgaveId,
                c__oppgavetype: oppgavetype
            }
        });
    }

    navigateToOppgaveTable() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__nksOppgaveTableRedirect' },
            state: {
                c__personIdent: null,
                c__actorId: null,
                c__ownedByRunningUser: 'true'
            }
        });
    }

    get hasOppgaver() {
        return this.oppgaver.length > 0;
    }

    get emptyState() {
        return !this.hasOppgaver && !this.isLoading;
    }

    get oppgaverWithPersonData() {
        return this.oppgaver.map((oppgave) => {
            const fullName = this.personData[oppgave.brukerIdent]?.CRM_FullName__c ?? oppgave.brukerIdent;
            const age = this.personData[oppgave.brukerIdent]?.CRM_Age__c;
            return {
                ...oppgave,
                personNameAndAge: age ? `${fullName} (${age} år)` : fullName
            };
        });
    }
}

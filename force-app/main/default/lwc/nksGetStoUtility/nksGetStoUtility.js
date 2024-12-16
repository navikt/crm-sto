import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getList from '@salesforce/apex/nksGetStoUtilityController.getList';
import getSto from '@salesforce/apex/nksGetStoUtilityController.getSto';
import getStoWithSkill from '@salesforce/apex/nksGetStoUtilityController.getStoWithSkill';
import getServiceResourceSkillIds from '@salesforce/apex/nksGetStoUtilityController.getServiceResourceSkillIds';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publishToAmplitude } from 'c/amplitude';

export default class NksGetStoUtility extends NavigationMixin(LightningElement) {
    records = [];
    isRefreshDisabled = false;
    showSpinner = false;
    pageurl;
    utilityId;
    getListResult;
    skillMap;
    value = 'All';

    get options() {
        const defaultLabel = [{ label: 'Alle tjenester jeg behandler', value: 'All' }];
        return this.skillMap
            ? defaultLabel.concat(Object.keys(this.skillMap).map((id) => ({ label: this.skillMap[id], value: id })))
            : defaultLabel;
    }

    get hasRecord() {
        return this.records.length > 0;
    }

    get hasCasesInProgress() {
        // eslint-disable-next-line compat/compat
        return this.records.some((record) => ['In progress', 'New'].includes(record.status));
    }

    get lastIndex() {
        return this.records.length - 1;
    }

    connectedCallback() {
        publishToAmplitude('STO', { type: 'STO Utility opened' });
        this.getUtilityId();
        this.setNavigationUrl();
    }

    @wire(getServiceResourceSkillIds)
    getSRSIds({ data, error }) {
        if (data) {
            this.skillMap = data.skillMap;
        }
        if (error) {
            console.error('Could not get SRS. Error: ', error);
        }
    }

    @wire(getList)
    wiredGetList(result) {
        this.getListResult = result;
        const { data, error } = result;

        if (data) {
            this.records = data;
        } else if (error) {
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map((e) => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        }
        this.showSpinner = false;
    }

    // Navigate to list
    setNavigationUrl() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'list' },
            state: { filterName: 'NKS_Case_STO_Not_Completed' }
        }).then((url) => {
            this.pageUrl = url;
        });
    }

    handleChange(event) {
        this.value = event.detail.value;
    }

    async getNewSTOHandler() {
        publishToAmplitude('STO', { type: 'getNewSTOHandler' });
        this.showSpinner = true;

        try {
            const records = this.value === 'All' ? await getSto() : await getStoWithSkill({ skillId: this.value });

            records.forEach((record) => this.openCase(record.recordId, record.status === 'In Progress'));
            this.minimizeSTOUtility();
        } catch (error) {
            this.handleGetStoError(error);
        } finally {
            this.refreshComponent();
        }
    }

    handleGetStoError(error) {
        const message = error?.body?.message;
        if (message === 'hasInProgress') {
            this.showToast('Warning', 'Du har allerede melding(er) under arbeid.', 'warning');
        } else if (message?.startsWith('Max Attempt')) {
            this.showToast('Warning', 'Kunne ikke hente ny melding. Prøv igjen.', 'warning');
        } else if (message?.startsWith('NotFound')) {
            this.showToast('Info', 'Ingen flere meldinger på tjenester du behandler.', 'info');
        } else {
            this.showToast('Error', message || 'Ukjent feil.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    minimizeSTOUtility() {
        if (this.utilityId) this.invokeUtilityBarAPI('minimizeUtility', { utilityId: this.utilityId });
    }

    getUtilityId() {
        this.invokeUtilityBarAPI('getAllUtilityInfo').then((allUtilityInfo) => {
            var stoUtility = allUtilityInfo.find((e) => {
                return e.utilityLabel === 'Hent ny melding'; //Matches the label of the utility component defined in app manager
            });
            if (stoUtility) {
                this.utilityId = stoUtility.id;
                this.registerClickHandler();
            }
        }, this);
    }

    registerClickHandler() {
        const eventHandler = () => {
            refreshApex(this.getListResult);
        };
        this.invokeUtilityBarAPI('onUtilityClick', { utilityId: this.utilityId, eventHandler: eventHandler });
    }

    openCase(caseId, focus) {
        return this.invokeWorkspaceAPI('openTab', { recordId: caseId, focus: focus });
    }

    navigateToList() {
        publishToAmplitude('STO', { type: 'navigateToList' });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'NKS_Case_STO_Not_Completed'
            }
        });
    }

    async refreshComponent() {
        this.showSpinner = true;
        this.isRefreshDisabled = true;
        publishToAmplitude('STO', { type: 'refreshComponent' });
        await refreshApex(this.getListResult);
        this.showSpinner = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            // 10 sec delay to avoid spamming refresh
            this.isRefreshDisabled = false;
        }, 10000);
    }

    invokeWorkspaceAPI(methodName, methodArgs) {
        return this.invokeAPI('workspaceAPI', methodName, methodArgs);
    }
    invokeUtilityBarAPI(methodName, methodArgs) {
        return this.invokeAPI('utilityBarAPI', methodName, methodArgs);
    }
    invokeAPI(apiName, methodName, methodArgs) {
        return new Promise((resolve, reject) => {
            const apiEvent = new CustomEvent('internalapievent', {
                bubbles: true,
                composed: true,
                cancelable: false,
                detail: {
                    category: apiName,
                    methodName: methodName,
                    methodArgs: methodArgs,
                    callback: (err, response) => {
                        if (err) {
                            return reject(err);
                        }
                        return resolve(response);
                    }
                }
            });

            window.dispatchEvent(apiEvent);
        });
    }
}

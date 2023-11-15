import { LightningElement, api, track } from 'lwc';
import getList from '@salesforce/apex/nksGetStoUtilityController.getList';
import getSto from '@salesforce/apex/nksGetStoUtilityController.getSto';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasStoBeta from '@salesforce/customPermission/STO_Beta';

export default class NksGetStoUtility extends NavigationMixin(LightningElement) {
    listCount = 5;
    @track records = [];

    showSpinner = false;
    isInitiated = false;
    pageurl;
    initRun = false;
    utilityId;

    betaPermission = hasStoBeta;

    connectedCallback() {
        this.getUtilityId();
        // Navigate to list
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'NKS_Case_STO_Not_Completed'
            }
        }).then((url) => {
            this.pageUrl = url;
        });
    }

    registerClickHandler() {
        let _this = this;
        const eventHandler = (event) => {
            _this.loadList();
        };
        this.invokeUtilityBarAPI('onUtilityClick', { utilityId: this.utilityId, eventHandler: eventHandler });
    }

    renderedCallback() {
        if (this.initRun === false) {
            this.initRun = true;
            this.loadList();
        }
    }

    getNewSTOHandler() {
        console.log('click');
        this.showSpinner = true;
        getSto()
            .then((records) => {
                console.log(records);
                records.forEach((record) => {
                    this.openCase(record.recordId, record.status === 'In Progress' ? true : false);
                }, this);
                this.minimizeSTOUtility();
            }, this)
            .catch((error) => {
                console.log(error);
                if (error.body.message === 'hasInProgress') {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Du har allerede melding(er) under arbeid.',
                            variant: 'warning'
                        })
                    );
                } else if (typeof error.body.message === 'string' && error.body.message.startsWith('Max Attempt')) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Kunne ikke hente ny melding.',
                            message: 'Prøv igjen.',
                            variant: 'warning'
                        })
                    );
                } else if (typeof error.body.message === 'string' && error.body.message.startsWith('NotFound')) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Kunne ikke hente ny melding.',
                            message: 'Ingen flere meldinger på køer du behandler.',
                            variant: 'info'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error.',
                            message: error.body.message,
                            variant: 'error'
                        })
                    );
                }
            })
            .finally(() => {
                this.loadList();
            }, this);
    }
    minimizeSTOUtility() {
        if (this.utilityId) this.invokeUtilityBarAPI('minimizeUtility', { utilityId: this.utilityId });
    }

    getUtilityId() {
        this.invokeUtilityBarAPI('getAllUtilityInfo').then((allUtilityInfo) => {
            var stoUtility = allUtilityInfo.find((e) => {
                //Matches the label of the utility component defined in app manager
                return e.utilityLabel === 'Hent ny melding';
            });
            if (stoUtility) {
                this.utilityId = stoUtility.id;
                this.registerClickHandler();
            }
        }, this);
    }

    openCase(caseId, focus) {
        return this.invokeWorkspaceAPI('openTab', { recordId: caseId, focus: focus });
    }
    loadList() {
        return getList({
            limitNumber: this.listCount
        })
            .then((data) => {
                this.records = data;
            })
            .catch((error) => {
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
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }

    navigateToList() {
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

    refreshList = () => {
        this.isInitiated = true;
        this.loadList();
    };

    loadMoreList() {
        this.listCount += 3;
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.loadList();
    }

    refreshComponent() {
        this.showSpinner = true;
        return this.loadList();
    }

    get hasRecord() {
        return this.records.length > 0 ? true : false;
    }

    get hasCasesInProgress() {
        try {
            return this.records.some((e) => e.status === 'In progress' || e.status === 'New');
        } catch {
            // skip
        }
        return false;
    }

    get lastIndex() {
        let index = 0;
        index = this.records.length - 1;
        return index;
    }

    //Helper method to invoke workspace API  from LWC
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

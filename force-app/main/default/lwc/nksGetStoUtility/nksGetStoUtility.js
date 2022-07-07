import { LightningElement, api, track } from 'lwc';
import getList from '@salesforce/apex/nksGetStoUtilityController.getList';
import getNewSTO from '@salesforce/apex/nksGetStoUtilityController.getNewSTO';
import getRelatedSTO from '@salesforce/apex/nksGetStoUtilityController.getRelatedSTO';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getDataConnectorSourceFields } from 'lightning/analyticsWaveApi';

export default class NksGetStoUtility extends NavigationMixin(LightningElement) {
    listCount = 5;
    @track records = [];

    showSpinner = false;
    isInitiated = false;
    pageurl;
    initRun = false;

    connectedCallback() {
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

    renderedCallback() {
        if (this.initRun === false) {
            this.initRun = true;
            this.loadList();
        }
    }
    getNewSTOHandler(){
        getNewSTO()
            .then(
                (caseId) => {
                    // TODO: Open Case, Open related cases, Close Utility bar
                    console.log(caseId);
                    this.openCase(caseId);
                    getRelatedSTO({caseId : caseId})
                            .then(
                                (relatedCaseIds) => {
                                    console.log(relatedCaseIds);
                                    relatedCaseIds?.forEach( element => {
                                        console.log(element);
                                        this.openCase(element);                                        
                                    });
                                }
                            )
                        ;
                }
            )
            .catch(
                (error) => {
                    // TODO: error handler
                    console.log(error);
                }
            )
        ;
    }
    openCase(caseId){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                actionName: 'view'
            }
        });
    }
    loadList() {
        getList({
            limitNumber: this.listCount
        })
            .then((data) => {
                this.records = data;
                return this.records;
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
    }

    loadMoreList() {
        this.listCount += 3;
        // eslint-disable-next-line @lwc/lwc/no-api-reassignments
        this.loadList();
    }

    refreshComponent() {
        this.showSpinner = true;
        this.loadList();
    }

    get hasRecord() {
        return this.records.length > 0 ? true : false;
    }

    get hasCasesInProgress() {
        try {
            return this.records.some(
                e => e.status ===  'In progress' ||  e.status === 'New'
            );
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
        return new Promise((resolve, reject) => {
            const apiEvent = new CustomEvent('internalapievent', {
                bubbles: true,
                composed: true,
                cancelable: false,
                detail: {
                    category: 'workspaceAPI',
                    methodName: methodName,
                    methodArgs: methodArgs,
                    callback: (err, response) => {
                        if (err) {
                            return reject(err);
                        } else {
                            return resolve(response);
                        }
                    }
                }
            });

            window.dispatchEvent(apiEvent);
        });
    }
}

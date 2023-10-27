({
    handleTabFocused: function (component, event, helper) {
        let focusedTabId = event.getParam('currentTabId');
        if (focusedTabId == null) {
            return;
        }
        let outputLog;
        let workspaceAPI = component.find('workspace');
        workspaceAPI
            .getTabInfo({
                tabId: focusedTabId
            })
            .then(function (response) {
                console.log('Response: ', response);
                console.log('Tab type: ', response.pageReference.type);
                switch (response.pageReference.type) {
                    case 'standard__recordPage':
                        // Record view
                        outputLog = {
                            isSubtab: response.isSubtab,
                            type: 'Record page',
                            recordId: response.recordId,
                            objectApiName: response.pageReference.attributes.objectApiName
                        };
                        break;

                    case 'standard__objectPage':
                        // List View / Create new record -  har attributes.actionName: 'List', Create har actionName 'new'
                        outputLog = {
                            isSubtab: response.isSubtab,
                            type:
                                response.pageReference.attributes.actionName === 'new'
                                    ? 'Create New Record'
                                    : 'List View',
                            objectApiName: response.pageReference.attributes.objectApiName
                        };
                        break;

                    case 'standard__recordRelationshipPage':
                        //  Related list
                        outputLog = { isSubtab: response.isSubtab, type: 'Related List' };
                        outputLog = Object.assign(outputLog, response.pageReference.attributes); // Spread operator is not supported so Object.assign does the job.
                        break;

                    case 'standard__navItemPage':
                        // A page that displays the content mapped to a custom tab. Visualforce tabs, web tabs, Lightning Pages, and Lightning Component tabs are supported.
                        outputLog = {
                            isSubtab: response.isSubtab,
                            type: 'Lightning Tab',
                            recordId: response.pageReference.state.ws.split('/')[4],
                            apiName: response.pageReference.attributes.apiName
                        };
                        break;

                    case 'standard__directCmpReference':
                        // Global search result
                        outputLog = {
                            isSubtab: response.isSubtab,
                            type: 'Global Search',
                            searchTerm: response.pageReference.attributes.attributes.term,
                            appName: response.pageReference.attributes.attributes.context.debugInfo.appName,
                            scope: response.pageReference.attributes.attributes.scopeMap.label
                        };
                        break;

                    default:
                        outputLog = {
                            isSubtab: response.isSubtab,
                            type: 'Unknown Type ' + response.pageReference.type,
                            recordId: response.recordId,
                            objectApiName: response.pageReference.attributes
                        };
                }
                outputLog.recordId = helper.anonymizeRecordId(component, outputLog.recordId);
                console.log('outputLog: ', JSON.stringify(outputLog));
                component.find('amplitude').trackAmplitudeEvent('Tab focused', outputLog);
            });
    },

    logMessage: function (component, message, helper) {
        const eventType = message.getParam('type');
        const currentRecordId = message.getParam('recordId');
        const objectToLog =
            message.getParam('options') === undefined ? {} : { recordId: '', options: message.getParam('options') }; // Null coalescing operator not supported...
        console.log('currentRecordId: ', currentRecordId);
        if (currentRecordId !== undefined) {
            objectToLog.recordId = helper.anonymizeRecordId(component, currentRecordId);
        }
        console.log('eventType: ', eventType);
        console.log('objectToLog: ', JSON.stringify(objectToLog));
        component.find('amplitude').trackAmplitudeEvent(eventType, objectToLog);
    },

    anonymizeRecordId: function (component, recordId) {
        if (recordId === undefined) {
            return null;
        }
        const recordIdMap = component.get('v.recordIdMap'); // Accessing the map from the component attribute
        if (recordIdMap.get(recordId) === undefined) {
            recordIdMap.set(recordId, crypto.randomUUID());
            component.set('v.recordIdMap', recordIdMap);
        }
        console.log('recordIdMap: ', recordIdMap);
        return recordIdMap.get(recordId);
    }
});

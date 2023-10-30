({
    handleTabFocused: function (component, event, helper) {
        let focusedTabId = event.getParam('currentTabId');
        if (focusedTabId == null) {
            return;
        }
        let recordId;
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
                            tabType: 'Record Page',
                            recordId: (recordId = response.recordId),
                            objectApiName: response.pageReference.attributes.objectApiName
                        };
                        break;

                    case 'standard__objectPage':
                        // List View / Create new record -  har attributes.actionName: 'List', Create har actionName 'new'
                        outputLog = {
                            isSubtab: response.isSubtab,
                            tabType:
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
                            tabType: 'Lightning Tab',
                            recordId: (recordId = response.pageReference.state.ws.split('/')[4]),
                            apiName: response.pageReference.attributes.apiName
                        };
                        break;

                    case 'standard__directCmpReference':
                        // Global search result
                        outputLog = {
                            isSubtab: response.isSubtab,
                            tabType: 'Global Search',
                            searchTerm: response.pageReference.attributes.attributes.term,
                            appName: response.pageReference.attributes.attributes.context.debugInfo.appName,
                            scope: response.pageReference.attributes.attributes.scopeMap.label
                        };
                        break;

                    default:
                        outputLog = {
                            isSubtab: response.isSubtab,
                            tabType: 'Unknown Type ' + response.pageReference.type,
                            recordId: (recordId = response.recordId),
                            objectApiName: response.pageReference.attributes
                        };
                }
                component.set('v.recordId', recordId); // Set current recordId in case it is not sent in logMessage to have fallback
                outputLog.recordId = helper.anonymizeRecordId(component, outputLog.recordId);
                console.log('outputLog: ', JSON.stringify(outputLog));
                component.find('amplitude').trackAmplitudeEvent('Tab focused', outputLog);
            });
    },

    logMessage: function (component, message, helper) {
        const eventType = message.getParam('eventType');
        const currentRecordId = message.getParam('recordId');
        const objectToLog =
            message.getParam('properties') === undefined
                ? {}
                : { recordId: '', properties: message.getParam('properties') }; // Null coalescing operator not supported...
        console.log('currentRecordId: ', currentRecordId);
        objectToLog.recordId = helper.anonymizeRecordId(
            component,
            currentRecordId === null || currentRecordId === undefined ? component.get('v.recordId') : currentRecordId
        );
        console.log('eventType: ', eventType);
        console.log('objectToLog: ', JSON.stringify(objectToLog));
        component.find('amplitude').trackAmplitudeEvent(eventType, objectToLog);
    },

    anonymizeRecordId: function (component, recordId) {
        if (recordId === undefined || recordId === null || recordId === '') {
            return '';
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

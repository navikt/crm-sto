({
    onTabCreated: function (component, event, helper) {
        var newTabId = event.getParam('tabId');
        var workspace = component.find('workspace');

        workspace.getAllTabInfo().then(function (response) {
            if (response.length === 1) {
                workspace
                    .isSubtab({
                        tabId: newTabId
                    })
                    .then(function (response) {
                        if (!response) {
                            workspace.focusTab({
                                tabId: newTabId
                            });
                        }
                    });
            }
        });
        workspace
            .getTabInfo({
                tabId: newTabId
            })
            .then(function (response) {
                var action = component.get('c.getTabName');
                action.setParams({ recordId: response.recordId });
                action.setCallback(this, function (data) {
                    if (data.getReturnValue() != null && data.getReturnValue().length > 0) {
                        workspace.setTabLabel({
                            tabId: newTabId,
                            label: data.getReturnValue()
                        });
                    }
                });
                $A.enqueueAction(action);
            });
    },

    doInit: function (component, event, helper) {
        var omniAPI = component.find('omniToolkit');
        var action = component.get('c.getOnlineId');

        action.setCallback(this, function (data) {
            console.log(data.getReturnValue());
            if (data.getReturnValue() != null && data.getReturnValue().length > 0) {
                console.log('IN Polling');
                var poll = setInterval(function () {
                    omniAPI
                        .login({ statusId: data.getReturnValue() })
                        .then(function (result) {
                            clearInterval(poll);
                        })
                        .catch(function (error) {
                            console.log(error);
                        });
                }, 2000);
            }
        });
        $A.enqueueAction(action);
    },

    onWorkAccepted : function(component, event, helper) {
        var workItemId = event.getParam('workItemId');
        var workId = event.getParam('workId');
        var flow = component.find("ChangeOwner");
        flow.startFlow("STO_Case_Set_Owner",
            [
                {
                    name : "WorkItemId",
                    type : "String",
                    value: workItemId
                }
            ]
        );
    },

    handleStatusChange : function (component, event) {
        if(event.getParam("status") === "FINISHED_SCREEN") {
           // Get flow response
           var outputVariables = event.getParam("outputVariables");
           var outputVar;
           var parentId; // var parentId = outputVariables.find(e => e.name === "WorkItemId").value;
           var childIds; // var childIds = outputVariables.find(e => e.name === "CasesToUpdate").value.map(e => e.Id);
           for(var i = 0; i < outputVariables.length; i++) {
                outputVar = outputVariables[i];
                if(outputVar.name === "CasesToUpdate") {
                    if(!outputVar.value) return;
                    childIds = outputVar.value.map(e => e.Id);
                } else if(outputVar.name === "WorkItemId"){
                    parentId = outputVar.value;
                } else if(outputVar.name === "ErrorMessage"){
                    if(outputVar.value){
                        console.log(outputVar.value);
                        return;
                    }
                } else {
                    // skip
                }
            }
            if(parentId && childIds.length > 0){
                let workspaceAPI = component.find("workspace");
                workspaceAPI
                    .getAllTabInfo()
                    .then(
                        (tabsInfo) => {
                            var tabInfo = tabsInfo
                                .find(
                                    (tabInfo) => {
                                        return tabInfo.recordId ? tabInfo.recordId.startsWith(parentId) : false;
                                    }
                                );
                            var parentTabId = tabInfo ? tabInfo.tabId : null;
                            childIds
                                .forEach(
                                    (childId) => {
                                        workspaceAPI
                                            .openSubtab(
                                                {
                                                    tabId: parentTabId,
                                                    recordId: childId
                                                }
                                            )
                                        ;
                                    }
                                )
                            ;
                        }
                    )
                    .catch(
                        (error) => {
                            console.log(JSON.stringify(error, null, 2));
                        }
                    )
                ;
            }
        }
    },
});
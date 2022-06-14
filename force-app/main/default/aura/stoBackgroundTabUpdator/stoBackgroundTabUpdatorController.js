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
                        workspace.setTabIcon({
                            tabId: newTabId,
                            icon: response.icon,
                            iconAlt: ' '
                        });
                    }
                });
                $A.enqueueAction(action);
            });
    },

    doInit: function (component, event, helper) {
        console.log("debug 9");
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
        console.log("Work accepted.");
        var workItemId = event.getParam('workItemId');
        var workId = event.getParam('workId');
        console.log(workItemId);
        console.log(workId);
        console.log("Hello from utility bar background!");
        var flow = component.find("ChangeOwner");
        console.log("flow should start");
        flow.startFlow("STO_Case_Set_Owner",
            [
                {
                    name : "WorkItemId",
                    type : "String",
                    value: workItemId
                },
                {
                    name : "WorkId",
                    type : "String",
                    value: workId
                }
            ]
        );
        console.log("flow started");
    },

    handleStatusChange : function (component, event) {
        console.log("flow status changed");
        console.log(event.getParam("status"));
        if(event.getParam("status") === "FINISHED_SCREEN") {
           // Get the output variables and iterate over them
           var outputVariables = event.getParam("outputVariables");
           console.log("flow output");
           console.log(outputVariables);
           var outputVar;
           var parentId;
           var childIds;
           for(var i = 0; i < outputVariables.length; i++) {
                outputVar = outputVariables[i];
                // Pass the values to the component's attributes
                if(outputVar.name === "CasesToUpdate") {
                    console.log("outputVar.value");
                    
                    console.log(outputVar.value);
                    if(!outputVar.value) return;
                    console.log(outputVar.value[0].Id);
                    
                    childIds = outputVar.value.map(e => e.Id);
                    console.log(childIds);
                } else if(outputVar.name === "WorkItemId"){
                    parentId = outputVar.value;
                } else {
                }
            }
            if(parentId && childIds.length > 0){
                let workspaceAPI = component.find("workspace");
                console.log("openTabs");
                workspaceAPI
                    .getAllTabInfo()
                    .then(
                        (tabsInfo) => {
                            console.log("tabsInfo:");
                            console.log(tabsInfo);
                            console.log("parentId");
                            console.log(parentId);
                            var tabInfo = tabsInfo
                                .find(
                                    (tabInfo) => {
                                        return tabInfo.recordId ? tabInfo.recordId.startsWith(parentId) : false;
                                    }
                                );
                            console.log("tabInfo");
                            console.log(tabInfo);
                            var parentTabId = tabInfo ? tabInfo.tabId : null;
                            console.log("parentTabId");
                            console.log(parentTabId);
                            childIds
                                .forEach(
                                    (childId) => {
                                        console.log("childId");
                                        console.log(childId);
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
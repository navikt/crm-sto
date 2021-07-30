({
    closeModal: function (component, event, helper) {
        component.set('v.showPanel', false);
    },

    handleToolbarAction: function (component, event, helper) {
        const flowName = event.getParam('flowName');
        const flowInputs = event.getParam('flowInputs');
        component.set('v.showPanel', true);

        const flow = component.find('panelFlow');
        flow.startFlow(flowName, flowInputs);
    }
});

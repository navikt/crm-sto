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
    },

    handleFlowStatusChange: function (component, event) {
        if (event.getParam('status') === 'FINISHED') {
            //Closes the modal when the flow finishes
            component.set('v.showPanel', false);
        }
    }
});

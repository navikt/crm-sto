({
    closeModal: function (component) {
        component.set('v.showPanel', false);
    },

    handleToolbarAction: function (component, event) {
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
    },

    handleModalKey: function (component, event) {
        if (event.keyCode === 27 || event.code === 'Escape') {
            var action = component.get('c.closeModal');
            $A.enqueueAction(action);
        } else if (event.keyCode === 9 || event.code === 'Tab') {
            const el = document.activeElement;
            if (el.classList.contains('lastfocusable') || el.classList.contains('firstfocusable')) {
                component.find('focusElement').getElement().focus();
            }
        }
    }
});

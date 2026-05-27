({
    getBobFeature: function (component) {
        var action = component.get('c.isFeatureEnabled');
        action.setParams({ featureName: 'Bob_Reporting_Data', toggleType: 'FEATURE_FLAG' });
        action.setCallback(this, function (response) {
            var state = response.getState();
            if (state === 'SUCCESS') {
                console.log('Feature flag check successful: ' + response.getReturnValue());
                var isEnabled = response.getReturnValue();
                component.set('v.isBobEnabled', isEnabled);
            } else {
                console.error('Error checking feature flag: ' + JSON.stringify(response.getError()));
            }
        });
        $A.enqueueAction(action);
    }
});

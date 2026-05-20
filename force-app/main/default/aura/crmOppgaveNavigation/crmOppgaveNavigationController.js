({
    init: function (component) {
        const pageRef = component.get('v.pageReference');
        if (!pageRef || !pageRef.state) return;
        const oppgaveId = pageRef.state.c__oppgaveId;
        const oppgavetype = pageRef.state.c__oppgavetype;
        const fromListView =
            pageRef.state.c__fromOppgaveListHome === true || pageRef.state.c__fromOppgaveListHome === 'true';
        component.find('oppgavePage').set('v.oppgaveId', oppgaveId);
        component.find('oppgavePage').set('v.showPersonInfo', fromListView);
        const workspace = component.find('workspace');
        workspace.getEnclosingTabId().then(function (tabId) {
            workspace.setTabLabel({ tabId: tabId, label: oppgavetype });
            workspace.setTabIcon({ tabId: tabId, icon: 'custom:custom45' });
        });
    }
});

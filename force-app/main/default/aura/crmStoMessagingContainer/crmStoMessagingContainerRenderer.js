({
    // Your renderer method overrides go here
    rerender: function (cmp, helper) {
        this.superRerender();
        // do custom rerendering here
        const modal = cmp.find('firstfocusable');
        if (modal) modal.getElement().focus();
    }
});

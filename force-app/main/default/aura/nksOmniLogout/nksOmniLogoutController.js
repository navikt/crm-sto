({
    invoke: function (component, event, helper) {
        var omniAPI = component.find("omniToolkit");
        omniAPI.logout(
        ).then(
            function(result){
                if(result){
                    // Successful logout
                }else{
                    console.log("Logout failed");
                }
            }
        ).catch(
            function(error){
                console.log(error);
            }
        );
    }
});

function loadCookie() {
    cookie = Cookies.getJSON('vce');
    if (cookie === undefined) {
        console.log('setting cookie');
        Cookies.set('vce', {workgroup: 'admin', switches: ['switch']});
    }
    /*
    {
        workgroup:      'ajco' // Name of the currently active workgroup
        switches:       ['sw'] // An array of all switches available to user
        switch:         'sw'   // Name of the currently selected switch
        selectedVlanId: ''     // Currently selected VLAN ID
    }
    */
}

function loadErrorCloseButton() {
    var errorCloseButton = document.getElementById("error_exit");
    var errorContainer = document.getElementById("error");

    errorCloseButton.onclick = function(e) {
        errorContainer.setAttribute('style', 'display: none;');
    };
}

function displayError(error) {
    var errorContainer = document.getElementById("error");
    var errorText = document.getElementById("error_text");

    errorText.innerText = error;
    errorContainer.setAttribute('style', 'display: block;');
}

// The var $allow_credentials in Method.pm must be set to 'true'
// for cors.
window.onload = function() {
    loadErrorCloseButton();
    loadCookie();
    cookie = Cookies.getJSON('vce');

    setHeader(cookie.switches);

    var url = window.location;
    if (url.pathname.indexOf('details.html') > -1) {
        selectTab();

        loadPorts();
        loadVlans();
        loadSwitch();
        
        loadPortCommands();
        loadSwitchCommands();
        loadVlanCommands();
        
        setInterval(loadPorts, 30000);
        setInterval(loadVlans, 30000);
    } else if (url.pathname.indexOf('create.html') > -1) {
        loadVlanDropdown();
        configureButtons();
    } else if (url.pathname.indexOf('edit.html') > -1) {
        loadVlanDropdown()
        .then(
            loadVlanDetails
        );
        configureEditButtons();
    } else {
        // Must be run first
        loadWorkgroups();
        
        loadSwitches();
        loadWorkgroup();
        
        setInterval(loadSwitches, 15000);
    }
}

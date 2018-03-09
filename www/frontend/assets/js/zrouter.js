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

function setDisplayMessage(type, text) {
    cookie = Cookies.getJSON('vce');
    cookie['message'] = {
        type: type,
        text: text
    };
    Cookies.set('vce', cookie);
}

function showDisplayMessage() {
    cookie = Cookies.getJSON('vce');
    if (!cookie.hasOwnProperty('message') || cookie.message === null) {
        return 1;
    }

    if (cookie.message.type === 'error') {
        displayError(cookie.message.text);
    } else if (cookie.message.type === 'success') {
        displaySuccess(cookie.message.text);
    } else {
        console.log(cookie.message);
    }

    cookie.message = null;
    Cookies.set('vce', cookie);
    return 1;
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

function loadSuccessCloseButton() {
    var successCloseButton = document.getElementById("success_exit");
    var successContainer = document.getElementById("success");

    successCloseButton.onclick = function(e) {
        successContainer.setAttribute('style', 'display: none;');
    };
}

function displaySuccess(success) {
    var successContainer = document.getElementById("success");
    var successText = document.getElementById("success_text");

    successText.innerText = success;
    successContainer.setAttribute('style', 'display: block;');

    setTimeout(function(e) {
        successContainer.setAttribute('style', 'display: none;');
    }, 7000);
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
        loadSuccessCloseButton();
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

    showDisplayMessage();
}

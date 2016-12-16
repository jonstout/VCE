function loadCookie() {
    cookie = Cookies.getJSON('vce');
    if (cookie === undefined) {
        console.log('setting cookie');
        Cookies.set('vce', {workgroup: 'ajco', switches: ['foobar']});
    }
}

// The var $allow_credentials in Method.pm must be set to 'true'
// for cors.
window.onload = function() {
    loadCookie();
    cookie = Cookies.getJSON('vce');
    
    setHeader(cookie.switches);
    
    var url = window.location;
    if (url.pathname.indexOf('details.html') > -1) {
        loadPorts();
        loadVlans();
        loadSwitch();
        
        setInterval(loadPorts, 30000);
        setInterval(loadVlans, 30000);
    } else if (url.pathname.indexOf('create.html') > -1) {
        loadVlanDropdown();
        configureButtons();
    } else {
        // Must be run first
        loadWorkgroups();
        
        loadSwitches();
        loadWorkgroup();
        
        setInterval(loadSwitches, 15000);
    }
}

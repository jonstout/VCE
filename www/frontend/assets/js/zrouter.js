function loadCookie() {
    cookie = Cookies.getJSON('vce');
    if (cookie === undefined) {
        console.log('setting cookie');
        Cookies.set('vce', {workgroup: 'ajco', switches: ['foobar']});
    }
}

window.onload = function() {
    loadCookie();
    cookie = Cookies.getJSON('vce');
    
    setHeader(cookie.switches);
    
    var url = window.location;
    if (url.pathname === '/vce/details.html') {
        loadPorts();
        loadVlans();
        loadSwitch();
        
        setInterval(loadPorts, 30000);
        setInterval(loadVlans, 30000);
    } else {
        // Get all workgroups for this user.
        // If the workgroup has not yet been set,
        // use the first found.
        loadWorkgroups();
        
        loadSwitches();
        loadWorkgroup();
        
        setInterval(loadSwitches, 15000);
    }
}

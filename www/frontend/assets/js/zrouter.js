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
    if (url.pathname === '/details.html') {
        loadPorts();
        loadVlans();
        loadSwitch(cookie.switch);
        
        setInterval(loadPorts, 30000);
        setInterval(loadVlans, 30000);
    } else {
        loadSwitches();
        loadWorkgroup();
        loadWorkgroups();
        
        setInterval(loadSwitches, 15000);
    }
}

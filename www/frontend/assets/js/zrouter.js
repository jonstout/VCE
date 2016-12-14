function loadCookie() {
    var text = document.cookie;
    if (text === '') {
        text = '{}';
    }
    
    var cookie = JSON.parse(text);
    cookie.workgroup = 'ajco';
    cookie.switches  = ['foobar'];
    
    document.cookie = JSON.stringify(cookie);
    return cookie;
}

window.onload = function() {
    cookie = loadCookie();
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
        loadWorkgroup(cookie.workgroup);
        
        setInterval(loadSwitches, 15000);
    }
}

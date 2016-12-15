function selectSwitch(e) {
    cookie = Cookies.getJSON('vce');
    cookie.switch = e.target.innerHTML;
    Cookies.set('vce', cookie);
}

function setHeader(switches) {    
    var dropd = document.getElementById("switch_menu");
    dropd.innerHTML = '';

    for (var i = 0; i < switches.length; i++) {
        var li = document.createElement("li");
        li.setAttribute('role', 'presentation');

        var link = document.createElement("a");
        link.innerHTML = switches[i];
        link.setAttribute('href', 'details.html');
        link.addEventListener("click", selectSwitch, false);

        li.appendChild(link);
        dropd.appendChild(li);
    }
}

function selectSwitch(obj) {
    var text = document.cookie;
    if (text === '') {
        text = '{}';
    }
    var cookie = JSON.parse(text);
    
    cookie.switch = obj;
    document.cookie = JSON.stringify(cookie);
    window.location.href = "http://127.0.0.1:55868/details.html";
}

function setHeader(switches) {    
    var dropd = document.getElementById("switch_menu");
    dropd.innerHTML = '';

    for (var i = 0; i < switches.length; i++) {
        var li = document.createElement("li");
        li.setAttribute('role', 'presentation');

        var link = document.createElement("a");
        link.setAttribute('href', 'details.html#');
        link.setAttribute('onclick', selectSwitch);
        link.innerHTML = switches[i];

        li.appendChild(link);
        dropd.appendChild(li);
    }
}

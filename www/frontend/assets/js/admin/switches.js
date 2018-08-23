window.onload = init;

async function init() {
    let switches = await getSwitches();
    renderSwitchList(switches);
};

function addSwitch(form) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let post = async function(data) {
        try {
            const url = '../api/switch.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `switches.html?switch_id=${obj.results[0].id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    form.workgroup.value = workgroup;

    let data = new FormData(form);
    post(data);
    return false;
}

async function getSwitches() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `switch.cgi?method=get_switches&workgroup=${workgroup}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) {
            console.log(data.error_text);
            return [];
        }
        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderSwitchList(switches) {
    let list = document.querySelector('#aside-list');
    let items = '';

    switches.forEach(function(sw) {
        items += `<li><a href="switches.html?switch_id=${sw.id}">${sw.name}</a></li>`;
    });

    list.innerHTML = items;
}

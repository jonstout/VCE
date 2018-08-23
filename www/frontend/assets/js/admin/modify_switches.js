window.onload = init;

async function init() {
    let switches = await getSwitches();
    renderSwitchList(switches);

    let params = new URLSearchParams(location.search);
    let switch_id = params.get('switch_id');

    let sw = await getSwitch(switch_id);
    renderSwitch(sw);
};

function modifySwitch(form) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let post = async function(data) {
        let id = data.get('id');

        try {
            const url = '../api/switch.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_switches.html?switch_id=${id}`;
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

async function getSwitch(switch_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `switch.cgi?method=get_switches&workgroup=${workgroup}&switch_id=${switch_id}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) {
            console.log(data.error_text);
            return null;
        }
        return data.results[0];
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderSwitch(sw) {
    let form = document.forms['modify-switch'];
    form.elements['id'].value = sw.id;
    form.elements['name'].value = sw.name;
    form.elements['description'].value = sw.description;
    form.elements['ip'].value = sw.ipv4;
    form.elements['ssh'].value = sw.ssh;
    form.elements['netconf'].value = sw.netconf;
    form.elements['vendor'].value = sw.vendor;
    form.elements['model'].value = sw.model;
    form.elements['version'].value = sw.version;
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

    let params = new URLSearchParams(location.search);
    let switch_id = params.get('switch_id');

    switches.forEach(function(sw) {
        if (sw.id == switch_id) {
            items += `<li><a class="is-active" href="modify_switches.html?switch_id=${sw.id}">${sw.name}</a></li>`;
        } else {
            items += `<li><a href="modify_switches.html?switch_id=${sw.id}">${sw.name}</a></li>`;
        }
    });

    list.innerHTML = items;
}

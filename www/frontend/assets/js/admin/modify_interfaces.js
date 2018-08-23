window.onload = init;

async function init() {
    getSwitches().then(function(switches) {
        renderSwitchList(switches);
    });

    let params = new URLSearchParams(location.search);
    let switch_id = params.get('switch_id');
    let interface_id = params.get('interface_id');

    getInterfaces(switch_id).then(function(intfs) {
        renderInterfaceList(intfs);
    });

    getInterface(interface_id).then(function(intf) {
        renderInterface(intf);
    });
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

function deleteSwitch() {
    let ok = confirm('Are you sure you wish to delete this device?');
    if (!ok) {
        return false;
    }

    let del = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let wg = cookie.workgroup;

        let id = data.get('id');
        let method = 'delete_switch';

        try {
            const url = `../api/switch.cgi?method=${method}&id=${id}&workgroup=${wg}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `switches.html`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    let form = document.forms['modify-switch'];
    let data = new FormData(form);
    del(data);
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

async function getInterface(interface_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `interface.cgi?method=get_interfaces&workgroup=${workgroup}&interface_id=${interface_id}`;
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

async function renderInterface(intf) {
    if (intf.description === '') { intf.description = '&nbsp;'; }

    document.querySelector('#name').innerHTML = `<b>Name:</b> ${intf.name}`;
    document.querySelector('#description').innerHTML = `<b>Description:</b> ${intf.description}`;

    document.querySelector('#hardware_type').innerHTML = `<b>Hardware:</b> ${intf.hardware_type}`;
    document.querySelector('#mac_addr').innerHTML = `<b>MAC Address:</b> ${intf.mac_addr}`;
    document.querySelector('#speed').innerHTML = `<b>Speed:</b> ${intf.speed}`;
    document.querySelector('#mtu').innerHTML = `<b>MTU:</b> ${intf.mtu}`;
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


async function getInterfaces(switch_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `interface.cgi?method=get_interfaces&workgroup=${workgroup}&switch_id=${switch_id}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) {
            console.log(data.error_text);
            return null;
        }
        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderInterfaceList(interfaces) {
    let list = document.querySelector('#aside2-list');
    let items = '';

    let params = new URLSearchParams(location.search);
    let switch_id = params.get('switch_id');
    let interface_id = params.get('interface_id');

    interfaces.forEach(function(intf) {
        if (intf.id == interface_id) {
            items += `<li><a class="is-active" href="modify_interfaces.html?switch_id=${switch_id}&interface_id=${intf.id}">${intf.name}</a></li>`;
        } else {
            items += `<li><a href="modify_interfaces.html?switch_id=${switch_id}&interface_id=${intf.id}">${intf.name}</a></li>`;
        }
    });

    if (interfaces.length === 0) {
        items += `<li><a>No interfaces</a></li>`;
    }
    list.innerHTML = items;
}

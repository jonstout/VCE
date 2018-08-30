window.onload = init;

async function init() {
    getWorkgroups().then(function(workgroups) {
        renderWorkgroupList(workgroups);
    });

    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    getWorkgroup(workgroup_id).then(function(wg) {
        renderWorkgroup(wg);
    });

    getInterfaces(workgroup_id).then(function(intfs) {
        renderInterfaceList(intfs);
    });

    getUsers(workgroup_id).then(function(users) {
        renderUserList(users);
    });

    getSwitches().then(function(switches) {
        renderSwitchSelect(switches);
    });

    document.querySelector('#workgroup-tab').addEventListener('click', function(e) {
        document.querySelector('#interface-tab').classList.remove("is-active");
        document.querySelector('#interface-tab-content').style.display = 'none';
        document.querySelector('#user-tab').classList.remove("is-active");
        document.querySelector('#user-tab-content').style.display = 'none';
        document.querySelector('#workgroup-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });
    document.querySelector('#interface-tab').addEventListener('click', function(e) {
        document.querySelector('#workgroup-tab').classList.remove("is-active");
        document.querySelector('#workgroup-tab-content').style.display = 'none';
        document.querySelector('#user-tab').classList.remove("is-active");
        document.querySelector('#user-tab-content').style.display = 'none';
        document.querySelector('#interface-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });
    document.querySelector('#user-tab').addEventListener('click', function(e) {
        document.querySelector('#interface-tab').classList.remove("is-active");
        document.querySelector('#interface-tab-content').style.display = 'none';
        document.querySelector('#workgroup-tab').classList.remove("is-active");
        document.querySelector('#workgroup-tab-content').style.display = 'none';
        document.querySelector('#user-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });

    setupAutoComplete();
};

function modifyWorkgroup(form) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let post = async function(data) {
        let id = data.get('id');

        try {
            const url = '../api/workgroup.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_workgroups.html?workgroup_id=${id}`;
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

function modifyInterface(form) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    let post = async function(data) {
        console.log(data);
        let id = data.get('workgroup_id');

        try {
            const url = '../api/interface.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_workgroups.html?workgroup_id=${id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    form.workgroup.value = workgroup;
    form.workgroup_id.value = workgroup_id;

    let data = new FormData(form);
    post(data);
    return false;
}

function resetInterfaceWorkgroup(id) {
    let ok = confirm('Are you sure you wish to remove an interface from this workgroup? The interface will be associated with the admin workgroup.');

    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    let post = async function(data) {
        try {
            const url = '../api/interface.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_workgroups.html?workgroup_id=${workgroup_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    let data = new FormData();
    data.set('method', 'update_interface');
    data.set('id', id);
    data.set('workgroup', workgroup);
    data.set('workgroup_id', 1);
    post(data);
    return false;
}

function deleteWorkgroup() {
    let ok = confirm('Are you sure you wish to delete this workgroup?');
    if (!ok) {
        return false;
    }

    let del = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let wg = cookie.workgroup;

        let id = data.get('id');
        let method = 'delete_workgroup';

        try {
            const url = `../api/workgroup.cgi?method=${method}&id=${id}&workgroup=${wg}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `workgroups.html`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    let form = document.forms['modify-workgroup'];
    let data = new FormData(form);
    del(data);
    return false;
}

async function getWorkgroup(workgroup_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_workgroups&workgroup=${workgroup}&workgroup_id=${workgroup_id}`;
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

async function renderWorkgroup(sw) {
    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    let form = document.forms['modify-workgroup'];
    form.elements['id'].value = sw.id;
    form.elements['name'].value = sw.name;
    form.elements['description'].value = sw.description;

    let iform = document.forms['add-workgroup-interface'];
    iform.elements['workgroup_id'].value = workgroup_id;
}

async function getWorkgroups() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_workgroups&workgroup=${workgroup}`;
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

async function renderWorkgroupList(workgroups) {
    let list = document.querySelector('#aside-list');
    let items = '';

    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    workgroups.forEach(function(workgroup) {
        if (workgroup.id == workgroup_id) {
            items += `<li><a class="is-active" href="modify_workgroups.html?workgroup_id=${workgroup.id}">${workgroup.name}</a></li>`;
        } else {
            items += `<li><a href="modify_workgroups.html?workgroup_id=${workgroup.id}">${workgroup.name}</a></li>`;
        }
    });

    list.innerHTML = items;
}

async function getInterfaces(workgroup_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `interface.cgi?method=get_interfaces&workgroup=${workgroup}&workgroup_id=${workgroup_id}`;
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

async function getSwitchInterfaces(switch_id) {
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
    let list = document.querySelector('#workgroup-interface-list');
    let items = '';

    let params = new URLSearchParams(location.search);
    let switch_id = params.get('switch_id');

    interfaces.forEach(function(intf) {
        items += `
<tr>
  <td>${intf.switch_name}</td><td>${intf.name}</td><td>${intf.hardware_type}</td><td>${intf.description}</td><td><a class="delete" onclick="resetInterfaceWorkgroup(${intf.id})"></a></td>
</tr>`;
    });

    list.innerHTML = items;
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
            return null;
        }
        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderSwitchSelect(switches) {
    let select = document.querySelector('#switch-select');
    let options = '';

    switches.forEach(function(sw) {
        options += `<option value=${sw.id}>${sw.name}</option>`;
    });
    select.innerHTML = options;

    loadSwitchInterfaces({value: switches[0].id});
}

function loadSwitchInterfaces(e) {
    getSwitchInterfaces(e.value).then(function(interfaces) {
        let select = document.querySelector('#interface-select');
        let options = '';

        interfaces.forEach(function(intf) {
            options += `<option value=${intf.id}>${intf.name}</option>`;
        });
        select.innerHTML = options;
    });
}


async function getUsersForAutoComplete(username) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let params = new URLSearchParams(location.search);
    let workgroup_id = params.get('workgroup_id');

    username = username === null ? '' : username;

    let url = '../' + baseUrl + `user.cgi?method=get_users&workgroup=${workgroup}&username=${username}`;
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

function setupAutoComplete() {
    let input = document.querySelector('#user-input');
    let autocomp = document.querySelector('#user-input-autocomplete');

    autocomp.style.maxHeight = '150px';
    autocomp.style.overflowY = 'scroll';
    autocomp.style.borderWidth = '1px';
    autocomp.style.borderStyle = 'solid';
    autocomp.style.borderColor = '#dbdbdb';
    autocomp.style.borderRadius = '5px';

    input.addEventListener('focusout', function(e) {
        setTimeout(function() { autocomp.style.display = 'none'; }, 250);
    });

    input.addEventListener('input', function(e) {
        if (e.target.value.length > 1) {
            getUsersForAutoComplete(e.target.value).then(function(users) {
                renderAutoCompleteSuggestions(users);
            });
            // loadAutoComplete(options);
            autocomp.style.display = 'block';
        } else {
            autocomp.style.display = 'none';
        }
    });
}

function setAutoCompleteValue(value, user_id) {
    let input = document.querySelector('#user-input');
    input.value = value;
    let id = document.querySelector('#user-input-id');
    id.value = user_id;
}

async function renderAutoCompleteSuggestions(values) {
    console.log(values);
    let select = document.querySelector('#user-input-autocomplete');
    let options = '';

    values.forEach(function(val) {
        options += `<li><a onclick="setAutoCompleteValue('${val.username}', ${val.id})">${val.username}</a></li>`
    });
    select.innerHTML = options;
}

async function getUsers(workgroup_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_workgroup_users&workgroup=${workgroup}&workgroup_id=${workgroup_id}`;
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

function addUserToWorkgroup(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let workgroup_id = params.get('workgroup_id');

        data.set('method', 'add_user_to_workgroup');
        data.set('workgroup', workgroup);
        data.set('workgroup_id', workgroup_id);

        try {
            const url = '../api/workgroup.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj  = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            window.location.href = `modify_workgroups.html?workgroup_id=${workgroup_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;
}

async function removeUserFromWorkgroup(user_workgroup_id) {
    let ok = confirm('Are you sure you wish to remove the user this workgroup?');
    if (!ok) {
        return false;
    }

    let del = async function() {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let workgroup_id = params.get('workgroup_id');

        try {
            const url = `../api/workgroup.cgi?method=remove_user_from_workgroup&workgroup=${workgroup}&user_workgroup_id=${user_workgroup_id}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_workgroups.html?workgroup_id=${workgroup_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    del();
    return false;
}

async function renderUserList(users) {
    let list = document.querySelector('#workgroup-user-list');
    let items = '';

    users.forEach(function(user) {
        items += `
<tr>
  <td>${user.username}</td>
  <td>${user.fullname}</td>
  <td>${user.email}</td>
  <td>
    <div class="select is-small">
    <select name="role">
    <option value="admin" ${user.role === 'admin' ? 'selected' : ''}>Admin</option>
    <option value="rw" ${user.role === 'rw' ? 'selected' : ''}>Read-Write</option>
    <option value="ro" ${user.role === 'ro' ? 'selected' : ''}>Read-Only</option>
    </select>
    </div>
  </td>
  <td><a class="delete" onclick="removeUserFromWorkgroup(${user.user_workgroup_id})"></a></td>
</tr>`;
    });

    list.innerHTML = items;
}

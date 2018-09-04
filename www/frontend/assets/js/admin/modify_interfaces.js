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

    document.querySelector('#interface-tab').addEventListener('click', function(e) {
        document.querySelector('#acl-tab').classList.remove("is-active");
        document.querySelector('#acl-tab-content').style.display = 'none';
        document.querySelector('#interface-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });
    document.querySelector('#acl-tab').addEventListener('click', function(e) {
        document.querySelector('#interface-tab').classList.remove("is-active");
        document.querySelector('#interface-tab-content').style.display = 'none';
        document.querySelector('#acl-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });

    // workgroups is required to render acl menus
    let workgroups = await getWorkgroups();
    let cookie = Cookies.getJSON('vce');
    cookie.workgroups = workgroups;
    Cookies.set('vce', cookie);
    renderWorkgroupSelection(workgroups);

    getACLs(interface_id).then(function(acls) {
        renderACLList(acls);
    });
};

async function renderWorkgroupSelection(workgroups) {
    let options = '';
    workgroups.forEach(function(workgroup) {
        options += `<option value="${workgroup.id}">${workgroup.name}</option>`;
    });

    document.querySelector('#workgroup-add-select').innerHTML = options;
}

async function getWorkgroups() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_workgroups&workgroup=${workgroup}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) throw data.error_text;

        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
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
    document.querySelector('#name').value = intf.name;
    document.querySelector('#description').value = intf.description;
    document.querySelector('#hardware_type').value = intf.hardware_type;
    document.querySelector('#mac_addr').value = intf.mac_addr;
    document.querySelector('#speed').value = intf.speed;
    document.querySelector('#mtu').value = intf.mtu;
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

function addACL(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let switch_id = params.get('switch_id');
        let interface_id = params.get('interface_id');

        data.set('method', 'add_acl');
        data.set('workgroup', workgroup);
        data.set('interface_id', interface_id);

        try {
            const url = '../api/acl.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            window.location.href = `modify_interfaces.html?switch_id=${switch_id}&interface_id=${interface_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;

}

async function getACLs(interface_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `acl.cgi?method=get_acls&workgroup=${workgroup}&interface_id=${interface_id}`;
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

function modifyACL(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let switch_id = params.get('switch_id');
        let interface_id = params.get('interface_id');

        data.set('method', 'modify_acl');
        data.set('workgroup', workgroup);

        try {
            const url = '../api/acl.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            window.location.href = `modify_interfaces.html?switch_id=${switch_id}&interface_id=${interface_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;
}

function deleteACL(id) {
    let ok = confirm('Are you sure you wish to delete this acl?');
    if (!ok) {
        return false;
    }

    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let switch_id = params.get('switch_id');
        let interface_id = params.get('interface_id');

        try {
            const url = `../api/acl.cgi?method=delete_acl&workgroup=${workgroup}&id=${id}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            window.location.href = `modify_interfaces.html?switch_id=${switch_id}&interface_id=${interface_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData());
    return false;
}

async function renderACLList(acls) {
    let list = document.querySelector('#acl-list');
    let cookie = Cookies.getJSON('vce');

    let items = '';

    acls.forEach(function(acl) {
        let options = '';
        cookie.workgroups.forEach(function(workgroup) {
            if (workgroup.id == acl.workgroup_id) {
                options += `<option value="${workgroup.id}" selected>${workgroup.name}</option>`;
            } else {
                options += `<option value="${workgroup.id}">${workgroup.name}</option>`;
            }
        });

        items += `
<form name="modify-acl-${acl.id}" onsubmit="return modifyACL(this)">
  <input class="input" type="hidden" name="id" value="${acl.id}" />

  <div class="field is-horizontal">
    <div class="field-body">
      <div class="field is-grouped">
        <div class="control">
          <input class="input" type="text" placeholder="2" name="low" required value="${acl.low}" />
        </div>
        <div class="control">
          <input class="input" type="text" placeholder="4095" name="high" requried value="${acl.high}"/>
        </div>
        <div class="control is-expanded" >
          <!-- width: 100% is a hack to expand select box -->
          <div class="select" style="width: 100%">
            <select name="workgroup_id" style="width: 100%" value="${acl.workgroup_id}">
              ${options}
            </select>
          </div>
        </div>
        <div class="control">
          <button type="submit" class="button is-link">Modify ACL</button>
          <button type="button" class="button is-danger is-outlined" onclick="return deleteACL(${acl.id})">
            <span>Delete</span>
            <span class="icon is-small">
              <i class="fas fa-times"></i>
            </span>
          </button>
        </div>
      </div>
    </div>
  </div>
</form>

`;
    });

    list.innerHTML = items;
}

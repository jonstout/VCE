window.onload = init;

async function init() {
    let params = new URLSearchParams(location.search);
    let command_id = params.get('command_id');

    getCommands().then(function(commands) {
        renderCommandList(commands);
    });

    getCommand(command_id).then(function(command) {
        renderCommand(command);
    });
};

function addCommand(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;
        let parameters = cookie.parameters;

        let ptype = data.get('type');
        if (ptype === 'interface' || ptype === 'vlan') {
            parameters.splice(0, 1);
        }

        data.set('method', 'add_command');
        data.set('parameters', JSON.stringify(parameters));
        data.set('workgroup', workgroup);

        try {
            const url = '../api/command.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            //window.location.href = `modify_commands.html?command_id=${obj.results[0].id}`;
            window.location.href = `commands.html?command_id=${obj.results[0].id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;
}

async function getCommand(command_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `command.cgi?method=get_command&workgroup=${workgroup}&command_id=${command_id}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) throw data.error_text;
        return data.results[0];
    } catch(error) {
        console.log(error);
        return [];
    }
}

function deleteCommand() {
    let ok = confirm('Are you sure you wish to delete this command?');
    if (!ok) {
        return false;
    }

    let del = async function() {
        let cookie = Cookies.getJSON('vce');
        let wg = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let id = params.get('command_id');

        let method = 'delete_command';

        try {
            const url = `../api/command.cgi?method=${method}&command_id=${id}&workgroup=${wg}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;
            window.location.href = `commands.html`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    del();
    return false;
}

async function renderCommand(command) {
    let cookie = Cookies.getJSON('vce');

    let form = document.forms['modify-command'];
    form.elements['command_id'].value = command.id;
    form.elements['name'].value = command.name;
    form.elements['description'].value = command.description;
    form.elements['template'].value = command.template;

    form.elements['operation'].value = command.operation;
    form.elements['type'].value = command.type;
    if (command.type === 'interface') {
        cookie.parameters = [{
            name: 'port',
            description: 'The interface name',
            regex: '^[A-Za-z]+$',
            type: 'input',
            disabled: true
        }];
    } else if (command.type === 'vlan') {
        cookie.parameters = [{
            name: 'vlan_id',
            description: 'The VLAN number',
            regex: '^[0-9]+$',
            type: 'input',
            disabled: true
        }];
    } else {
        cookie.parameters = [];
    }
    Cookies.set('vce', cookie);
    renderParameterList();

    command.parameters.forEach(function(param) {
        addParameter(param.name, param.description, param.regex, param.type, param.disabled, param.id);
    });
}

function modifyCommand(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;
        let parameters = cookie.parameters;

        let params = new URLSearchParams(location.search);
        let command_id = params.get('command_id');

        let ptype = data.get('type');
        if (ptype === 'interface' || ptype === 'vlan') {
            parameters.splice(0, 1);
        }

        data.set('method', 'modify_command');
        data.set('parameters', JSON.stringify(parameters));
        data.set('workgroup', workgroup);

        try {
            const url = '../api/command.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;
            window.location.href = `modify_commands.html?command_id=${command_id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;
}

async function getCommands() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `command.cgi?method=get_commands&workgroup=${workgroup}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) throw data.error_text;
        return data.results;
    } catch(error) {
        console.log(error);
        return [];
    }
}

async function renderCommandList(commands) {
    let list = document.querySelector('#aside-list');
    let items = '';

    let intfs = '';
    let switches = '';
    let vlans = '';

    commands.forEach(function(command) {
        if (command.type === 'interface') {
            intfs += `<li><a href="modify_commands.html?command_id=${command.id}">${command.name}</a></li>`;
        } else if (command.type === 'switch') {
            switches += `<li><a href="modify_commands.html?command_id=${command.id}">${command.name}</a></li>`;
        } else {
            vlans += `<li><a href="modify_commands.html?command_id=${command.id}">${command.name}</a></li>`;
        }
    });

    list.innerHTML = `
<p class="menu-label">Interface</p>
<ul class="menu-list">
  ${intfs}
</ul>
<p class="menu-label">Switch</p>
<ul class="menu-list">
  ${switches}
</ul>
<p class="menu-label">VLAN</p>
<ul class="menu-list">
  ${vlans}
</ul>
`;
}

async function loadDefaultParameters() {
    let cookie = Cookies.getJSON('vce');
    cookie.parameters = [{
        name: 'port',
        description: 'The interface name',
        regex: '^[A-Za-z]+$',
        type: 'input',
        disabled: true
    }];
    Cookies.set('vce', cookie);
    return true;
}

async function addParameter(name='', description='', regex='', type='input', disabled=false, id=-1) {
    let cookie = Cookies.getJSON('vce');
    cookie.parameters.push({
        name: name,
        description: description,
        regex: regex,
        type: type,
        disabled: disabled,
        id: id
    });
    Cookies.set('vce', cookie);
    renderParameterList();
}

function updateCommandType(radio) {
    let cookie = Cookies.getJSON('vce');

    if (cookie.parameters.length == 0) {
        if (radio.value === 'interface') {
            cookie.parameters.splice(0, 1, {
                name: 'port',
                description: 'The interface name',
                regex: '^[A-Za-z]+$',
                type: 'input',
                disabled: true
            });
        }
        if (radio.value === 'vlan') {
            cookie.parameters.splice(0, 1, {
                name: 'vlan_id',
                description: 'The VLAN number',
                regex: '^[0-9]+$',
                type: 'input',
                disabled: true
            });
        }
        Cookies.set('vce', cookie);
        return renderParameterList();
    }

    let name = cookie.parameters[0].name;

    if (radio.value === 'interface') {
        if (name === 'port') {
            // do nothing
        } else if (name === 'vlan_id') {
            cookie.parameters[0].name = 'port';
            cookie.parameters[0].description = 'The interface name';
            cookie.parameters[0].regex = '^[A-Za-z]+$';
            cookie.parameters[0].type = 'input';
            cookie.parameters[0].disabled = true;
        } else {
            cookie.parameters.splice(0, 0, {
                name: 'port',
                description: 'The interface name',
                regex: '^[A-Za-z]+$',
                type: 'input',
                disabled: true
            });
        }
    } else if (radio.value === 'switch') {
        if (name === 'switch') {
            // do nothing
        } else if (name === 'vlan_id') {
            cookie.parameters.splice(0, 1);
        } else if (name === 'port') {
            cookie.parameters.splice(0, 1);
        }
    } else if (radio.value === 'vlan') {
        if (name === 'vlan_id') {
            // do nothing
        } else if (name === 'port') {
            cookie.parameters[0].name = 'vlan_id';
            cookie.parameters[0].description = 'The VLAN number';
            cookie.parameters[0].regex = '^[0-9]+$';
            cookie.parameters[0].type = 'input';
            cookie.parameters[0].disabled = true;
        } else {
            cookie.parameters.splice(0, 0, {
                name: 'vlan_id',
                description: 'The VLAN number',
                regex: '^[0-9]+$',
                type: 'input',
                disabled: true
            });
        }
    } else {
        return 1;
    }

    Cookies.set('vce', cookie);
    renderParameterList();
}

function deleteParameter(index) {
    let cookie = Cookies.getJSON('vce');
    cookie.parameters.splice(index, 1);
    Cookies.set('vce', cookie);
    renderParameterList();
}

function updateParameter(index) {
    let cookie = Cookies.getJSON('vce');
    cookie.parameters[index].name = document.querySelector(`#pname-${index}`).value;
    cookie.parameters[index].description = document.querySelector(`#pdescription-${index}`).value;
    cookie.parameters[index].regex = document.querySelector(`#pregex-${index}`).value;
    if (document.querySelector(`#ptype-input-${index}`).checked) {
        cookie.parameters[index].type = 'input';
    } else {
        cookie.parameters[index].type = 'option';
    }
    Cookies.set('vce', cookie);
}

async function renderParameterList() {
    let list = document.querySelector('#parameters-list');
    let items = '';

    let cookie = Cookies.getJSON('vce');
    cookie.parameters.forEach(function(param, i) {
        items += `
<div class="field">
  <label class="label">Name</label>
  <div class="control">
    <input class="input" type="text" id="pname-${i}" placeholder="integer" value="${param.name}" required ${(param.disabled) ? 'disabled' : ''} onblur="updateParameter(${i})"/>
  </div>
</div>
<div class="field">
  <label class="label">Description</label>
  <div class="control">
    <input class="input" type="text" id="pdescription-${i}" placeholder="Example that takes an integer" value="${param.description}" required ${(param.disabled) ? 'disabled' : ''} onblur="updateParameter(${i})"/>
  </div>
</div>
<div class="field">
  <label class="label">Regex</label>
  <div class="control">
    <input class="input" type="text" id="pregex-${i}" placeholder="^[0-9]+$" value="${param.regex}" required ${(param.disabled) ? 'disabled' : ''} onblur="updateParameter(${i})" />
  </div>
</div>
<div class="field">
  <label class="label">Type</label>
  <label class="radio">
    <input type="radio" id="ptype-input-${i}" name="ptype-${i}" ${(param.type == 'input') ? 'checked' : ''} ${(param.disabled) ? 'disabled' : ''} onblur="updateParameter(${i})" />
    Input
  </label>
  <label class="radio">
    <input type="radio" id="ptype-option-${i}" name="ptype-${i}" ${(param.type == 'option') ? 'checked' : ''} ${(param.disabled) ? 'disabled' : ''} onblur="updateParameter(${i})" />
    Option
  </label>
</div>

<div class="field is-grouped">
  <div class="control">
    <button type="button" class="button is-danger is-outlined" ${(param.disabled) ? 'disabled' : ''} onclick="deleteParameter(${i})">
      <span>Remove Parameter</span>
      <span class="icon is-small"><i class="fas fa-times"></i></span>
    </button>
  </div>
</div>
<hr/>
`;
    });

    list.innerHTML = items;
}

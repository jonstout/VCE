function loadSwitch() {
    var cookie = Cookies.getJSON('vce');
    var sw = cookie.switch;
    
    var url = baseUrl + 'operational.cgi?method=get_workgroup_operational_status';
    url += '&workgroup=' + cookie.workgroup;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var switches = data.results[0].workgroups;

            for (var i = 0; i < switches.length; i++) {
                if (switches[i].name === sw) {
                    var name = document.getElementById("switch_name");
                    name.innerHTML = switches[i].name;
                    
                    var crumb = document.getElementById("switch_name_crumb");
                    crumb.innerHTML = switches[i].name;
                    
                    var desc = document.getElementById("switch_description");
                    desc.innerHTML = switches[i].description;
                    
                    var status = document.getElementById("switch_status");
                    status.innerHTML = switches[i].status;
                    
                    var vlan = document.getElementById("switch_vlans");
                    var vlans_up = switches[i].up_vlans;
                    var vlans_dn = switches[i].total_vlans - switches[i].up_vlans;
                    vlan.innerHTML = `▲ ${vlans_up} &nbsp;&nbsp; ▼ ${vlans_dn}`;

                    var ports = document.getElementById("switch_ports");
                    var ports_up = switches[i].up_ports;
                    var ports_dn = switches[i].total_ports - switches[i].up_ports;
                    ports.innerHTML = `▲ ${ports_up} &nbsp;&nbsp; ▼ ${ports_dn}`;
                }
            }
        });
    });
    
    var name = document.getElementById('switch_name');
    name.innerHTML = sw.name;
    
    var description = document.getElementById('switch_description');
    description.innerHTML = sw.description;
    
    var status = document.getElementById('switch_status');
    status.innerHTML = sw.status;
    
    var vlans = document.getElementById('switch_vlans');
    vlans.innerHTML = sw.vlans;
    
    var ports = document.getElementById('switch_ports');
    ports.innerHTML = sw.ports;
}

function loadPorts() {
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    
    var url = baseUrl + 'operational.cgi?method=get_interfaces_operational_status';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + name;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var table = document.getElementById("port_table");
            table.innerHTML = "";
            var ports = data.results[0].ports;
            
            for (var i = 0; i < ports.length; i++) {
                var row = table.insertRow(0);
                row.id = ports[i].name;
                row.setAttribute('class', 'clickable-row');

                var name = row.insertCell(0);
                name.innerHTML = ports[i].name;
                
                var desc = row.insertCell(1);
                desc.innerHTML = ports[i].description;
                
                var vlan = row.insertCell(2);
                vlan.innerHTML = ports[i].tags.toString();
                
                var status = row.insertCell(3);
                if (ports[i].status === 1) {
                    status.innerHTML = 'Up';
                } else {
                    status.innerHTML = 'Down';
                }

                if (ports[i].admin_status === 0) {
                    status.innerHTML = 'Disabled';
                }
            }
            
            $('#port_table').on('click', '.clickable-row', function(e) {
                $(this).addClass('active').siblings().removeClass('active');
                
                var cookie = Cookies.getJSON('vce');
                cookie.port = $(this)[0].id;
                Cookies.set('vce', cookie);
            });
        });
    });
}

function navigateOnSelect(e) {
    var command = e.target.selectedOptions[0].value;
    
    var cookie    = Cookies.getJSON('vce');
    var name      = cookie.switch;
    var vlanId    = cookie.selectedVlanId;
    var workgroup = cookie.workgroup;
    
    if (command === 'add_vlan') {
        window.location.href = 'create.html';
    }
    
    if (command === 'edit_vlan') {
        window.location.href = 'edit.html';
    }
    
    if (command === 'delete_vlan') {
        var url = baseUrl + 'provisioning.cgi?method=delete_vlan';
        url += '&workgroup=' + workgroup;
        url += '&vlan_id=' + vlanId;

        fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
            response.json().then(function(data) {
                if (typeof data.error !== 'undefined') {
                    return displayError(data.error.msg);
                }

                window.location.href = 'details.html';
            });
        });
    }
}

function loadVlans() {
    var create = document.getElementById('vlan_select');
    create.addEventListener("change", navigateOnSelect, false);
    
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    
    var url = baseUrl + 'access.cgi?method=get_vlans';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + name;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var vlans = data.results[0].vlans;
            var table = document.getElementById("vlan_table");
            table.innerHTML = '';
            
            for (var i = 0; i < vlans.length; i++) {
                var row = table.insertRow(0);
                row.id = vlans[i].vlan_id;
                row.setAttribute('class', 'clickable-row');

                var vlan = row.insertCell(0);
                vlan.innerHTML = vlans[i].vlan;

                var desc = row.insertCell(1);
                desc.innerHTML = vlans[i].description;

                var ports = row.insertCell(2);
                ports.innerHTML = '';
                for (var j = 0; j < vlans[i].endpoints.length; j++) {
                    if (j === 0) {
                        ports.innerHTML = vlans[i].endpoints[j].port;
                        continue;
                    }
                    ports.innerHTML += ', ' + vlans[i].endpoints[j].port;
                }

                var status = row.insertCell(3);
                status.innerHTML = vlans[i].status;
            }
            
            $('#vlan_table').on('click', '.clickable-row', function(e) {
                $(this).addClass('active').siblings().removeClass('active');
                
                var cookie = Cookies.getJSON('vce');
                cookie.selectedVlanId = $(this)[0].id;
                Cookies.set('vce', cookie);
            });
        });
    });
}

function loadPortCommands() {
    var cookie = Cookies.getJSON('vce');
    
    $('#port_select').change(function(e) {
        var form = $('#' + e.target.value);
        form.css("display", "block");
        form.siblings().css("display", "none");
    });
    
    var url = baseUrl + 'access.cgi?method=get_port_commands';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + cookie.switch;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cmds = data.results;
            
            for (var i = 0; i < cmds.length; i++) {
                var commandForm = NewCommandForm(cmds[i], function(raw) {
                    var well = document.getElementById("port_response_well");
                    well.innerHTML = "";

                    var pre = document.createElement("pre");
                    pre.innerHTML = raw;
                    well.appendChild(pre);
                });
                
                var formContainer = document.getElementById("port_form_container");
                formContainer.appendChild(commandForm);
                
                var opt = document.createElement('option');
                opt.innerHTML = cmds[i].name;
                opt.setAttribute('value', cmds[i].method_name);
                
                if (cmds[i].type == "show") {
                    document.getElementById("port_show_commands").appendChild(opt);
                } else {
                    document.getElementById("port_action_commands").appendChild(opt);
                }
            }
        });
    });
}

function loadSwitchCommands() {
    var cookie = Cookies.getJSON('vce');
    
    $('#switch_select').change(function(e) {
        var form = $('#' + e.target.value);
        form.css("display", "block");
        form.siblings().css("display", "none");
    });
    
    var url = baseUrl + 'access.cgi?method=get_switch_commands';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + cookie.switch;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cmds = data.results;
            
            for (var i = 0; i < cmds.length; i++) {
                var commandForm = NewCommandForm(cmds[i], function(raw) {
                    var well = document.getElementById("switch_response_well");
                    well.innerHTML = "";

                    var pre = document.createElement("pre");
                    pre.innerHTML = raw;
                    well.appendChild(pre);
                });
                
                var formContainer = document.getElementById("switch_form_container");
                formContainer.appendChild(commandForm);
                
                var opt = document.createElement('option');
                opt.innerHTML = cmds[i].name;
                opt.setAttribute('value', cmds[i].method_name);
                
                if (cmds[i].type == "show") {
                    document.getElementById("switch_show_commands").appendChild(opt);
                } else {
                    document.getElementById("switch_action_commands").appendChild(opt);
                }
            }
        });
    });
}

function loadVlanCommands() {
    var cookie = Cookies.getJSON('vce');
    
    $('#vlan_select').change(function(e) {
        var form = $('#' + e.target.value);
        form.css("display", "block");
        form.siblings().css("display", "none");
    });
    
    var url = baseUrl + 'access.cgi?method=get_vlan_commands';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + cookie.switch;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cmds = data.results;
            
            for (var i = 0; i < cmds.length; i++) {
                var commandForm = NewCommandForm(cmds[i], function(raw) {
                    var well = document.getElementById("vlan_response_well");
                    well.innerHTML = "";

                    var pre = document.createElement("pre");
                    pre.innerHTML = raw;
                    well.appendChild(pre);
                });
                
                var formContainer = document.getElementById("vlan_form_container");
                formContainer.appendChild(commandForm);
                
                var opt = document.createElement('option');
                opt.innerHTML = cmds[i].name;
                opt.setAttribute('value', cmds[i].method_name);
                
                if (cmds[i].type == "show") {
                    document.getElementById("vlan_show_commands").appendChild(opt);
                } else {
                    document.getElementById("vlan_action_commands").appendChild(opt);
                }
            }
        });
    });
}

function selectTab() {
    var searchParams = new URLSearchParams(location.search.slice(1));
    var tabSelection = searchParams.get("tab");

    if (tabSelection === null) {
        tabSelection = "switch";
    }

    $('a[href="#' + tabSelection + '"]').tab('show');
}

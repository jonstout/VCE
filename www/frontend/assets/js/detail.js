function loadSwitch() {
    var cookie = Cookies.getJSON('vce');
    var sw = cookie.switch;
    
    var url = baseUrl + 'operational.cgi?method=get_workgroup_operational_status';
    url += '&workgroup=' + cookie.workgroup;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
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
                    vlan.innerHTML = switches[i].up_vlans.toString() + "/" + switches[i].total_vlans.toString();
                    
                    var ports = document.getElementById("switch_ports");
                    ports.innerHTML = switches[i].up_ports.toString() + "/" + switches[i].total_ports.toString();
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
            var table = document.getElementById("port_table");
            table.innerHTML = "";
            var ports = data.results[0].ports;
            
            for (var i = 0; i < ports.length; i++) {
                var row = table.insertRow(0);
                row.id = ports[i].name;

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
            }
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
                window.location.href = 'details.html';
            });
        });
    }
}

function loadVlans() {
    var create = document.getElementById('vlan_command');
    create.addEventListener("change", navigateOnSelect, false);
    
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    
    var url = baseUrl + 'access.cgi?method=get_vlans';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + name;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
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

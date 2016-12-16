function loadVlanDropdown() {
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    var workgroup = cookie.workgroup;
    
    var crumb = document.getElementById("switch_name_crumb");
    crumb.innerHTML = name;
    
    var url = 'https://jonstout-dev.grnoc.iu.edu/vce/api/operational.cgi?method=get_interfaces_operational_status';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + name;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var ports = data.results[0].ports;
            
            var dropd = document.getElementById("vlan_optgroup");
            dropd.innerHTML = '';
            
            var endpoints_a = document.getElementById('endpoint_a_optgroup');
            endpoints_a.innerHTML = '';
            
            var endpoints_z = document.getElementById('endpoint_z_optgroup');
            endpoints_z.innerHTML = '';
            
            // Loads valid VLANS
            for (var i = 0; i < ports[0].tags.length; i++) {
                var opt = document.createElement('option');
                opt.innerHTML = ports[0].tags[i];
                opt.setAttribute('value', ports[0].tags[i]);
                dropd.appendChild(opt);
            }
            
            // Loads valid endpoints
            for (var i = 0; i < ports.length; i++) {
                var opt_a = document.createElement('option');
                opt_a.innerHTML = ports[i].name;
                opt_a.setAttribute('value', ports[i].name);
                
                var opt_z = document.createElement('option');
                opt_z.innerHTML = ports[i].name;
                opt_z.setAttribute('value', ports[i].name);
                
                endpoints_a.appendChild(opt_a);
                endpoints_z.appendChild(opt_z);
            }
        });
    });
}

function configureButtons() {
    var create = document.getElementById('create_button');
    create.addEventListener("click", createVlan, false);
    
    var cancel = document.getElementById('cancel_button');
    cancel.addEventListener("click", cancelVlan, false);
}

function createVlan(e) {
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    var workgroup = cookie.workgroup;
    
    var desc = document.getElementById('description');
    var text = desc.value;
    
    var vlan = document.getElementById('vlan');
    var vlan_id = vlan.options[vlan.selectedIndex].value;
    
    var endpoint_a = document.getElementById('endpoint_a');
    var a = endpoint_a.options[endpoint_a.selectedIndex].value;
    
    var endpoint_z = document.getElementById('endpoint_z');
    var z = endpoint_z.options[endpoint_z.selectedIndex].value;

    console.log(text);
    console.log(vlan_id);
    console.log(a);
    console.log(z);
    
    var url = 'https://jonstout-dev.grnoc.iu.edu/vce/api/provisioning.cgi?method=add_vlan';
    url += '&workgroup=' + workgroup;
    url += '&description=' + text;
    url += '&switch' + name;
    url += '&port=' + a;
    url += '&vlan=' + vlan_id;
    url += '&switch=' + name;
    url += '&port=' + z;
    url += '&vlan=' + vlan_id;
    
    console.log(url);
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            window.location.href = 'details.html';
        });
    });
}

function cancelVlan(e) {
    window.location.href = 'details.html';
}

function configureEditButtons() {
    var create = document.getElementById('edit_button');
    create.addEventListener("click", editVlan, false);
    
    var cancel = document.getElementById('cancel_button');
    cancel.addEventListener("click", cancelVlan, false);
}

function loadVlanDetails() {
    var cookie    = Cookies.getJSON('vce');
    var name      = cookie.switch;
    var vlanId    = cookie.selectedVlanId;
    var workgroup = cookie.workgroup;
    
    var crumb = document.getElementById("switch_name_crumb");
    crumb.innerHTML = name;
    
    var url = baseUrl + 'access.cgi?method=get_vlan_details';
    url += '&workgroup=' + workgroup;
    url += '&vlan_id=' + vlanId;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var circuit = data.results[0].circuit;
            console.log(circuit);
            
            var desc = document.getElementById('description');
            desc.value = circuit.description;

            var vlan = document.getElementById('vlan');
            for (var i = 0; i < vlan.options.length; i++) {
                if (vlan.options[i].value == circuit.vlan) {
                    vlan.selectedIndex = i;
                    break;
                }
            }

            var endpoint_a = document.getElementById('endpoint_a');
            for (var i = 0; i < endpoint_a.options.length; i++) {
                if (endpoint_a.options[i].value == circuit.endpoints[0].port) {
                    endpoint_a.selectedIndex = i;
                    break;
                }
            }

            var endpoint_z = document.getElementById('endpoint_z');
            for (var i = 0; i < endpoint_z.options.length; i++) {
                if (endpoint_z.options[i].value == circuit.endpoints[1].port) {
                    endpoint_z.selectedIndex = i;
                    break;
                }
            }
        });
    });
}


function editVlan(e) {
    var cookie    = Cookies.getJSON('vce');
    var name      = cookie.switch;
    var vlanId    = cookie.selectedVlanId;
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
    console.log(vlanId);
    
    var url = baseUrl + 'provisioning.cgi?method=edit_vlan';
    url += '&workgroup=' + workgroup;
    url += '&description=' + text;
    url += '&switch=' + name;
    url += '&port=' + a;
    url += '&vlan=' + vlan_id;
    url += '&switch=' + name;
    url += '&port=' + z;
    url += '&vlan=' + vlan_id;
    url += '&vlan_id=' + vlanId;
    
    console.log(url);
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            window.location.href = 'details.html';
        });
    });
}

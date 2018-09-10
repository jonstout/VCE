var endpointOptions = [];
var portTags = {};
function loadVlanDropdown() {
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    var workgroup = cookie.workgroup;

    var crumb = document.getElementById("switch_name_crumb");
    crumb.innerHTML = name;

    var url = baseUrl + 'operational.cgi?method=get_interfaces_operational_status';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + name;
    return fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var ports = data.results[0].ports;

            var dropd = document.getElementById("vlan_optgroup");
            dropd.innerHTML = '';
            var opt = document.createElement('option');
            opt.innerHTML = "Add and select an endpoint to filter VLANS";
            // opt.setAttribute('value', vlanIds[i]);
            dropd.appendChild(opt);

            // Loads valid VLANS
            var low   = 1;
            var high  = 0;


            var vlanIds = [];
            for (var i = 0; i < ports.length; i++) {

                for (var j = 0; j < ports[i].tags.length; j++) {
                    // if (ports[0].tags.length > 0) {
                    var parts = ports[i].tags[j].split("-").map(Number);
                    low   = parts[0];
                    high  = parts[0];

                    if (parts.length > 1) {
                        high = parts[1];
                    }
                    // }

                    for (var k = low; k <= high; k++) {
                        if (vlanIds.includes(k)) {
                            continue;
                        }
                        vlanIds.push(k);
                    }
                }
            }
            var url = baseUrl + 'access.cgi?method=get_vlans';
            url += '&workgroup=' + cookie.workgroup;
            url += '&switch=' + name;
            fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
                response.json().then(function(data) {
                    if (typeof data.error !== 'undefined') {
                        return displayError(data.error.msg);
                    }

                    var _vlans = data.results[0]['vlans'];
                    var provisionedVlans = {};
                    for (var i = 0; i < _vlans.length; i++) {
                        provisionedVlans[_vlans[i]['vlan']] = true;
                    }


                    vlanIds.sort(function(a, b){return a - b});
                    for (var i = 0; i < vlanIds.length; i++) {
                        if (vlanIds[i] in provisionedVlans) {
                            continue;
                        }

                        var opt = document.createElement('option');
                        opt.innerHTML = vlanIds[i];
                        opt.setAttribute('value', vlanIds[i]);
                        dropd.appendChild(opt);
                    }
                });
            });


            // Loads valid endpoints
            for (var i = 0; i < ports.length; i++) {
                endpointOptions.push(ports[i].name);
            }

            // Loads valid endpoints
            for (var i = 0; i < ports.length; i++) {
                portTags[ports[i].name] = ports[i].tags;
            }
        });
    });
}

function createEndpointSelector() {
    var container = document.getElementById('endpoint-container');
    container.addEventListener('change', function() {
        filterVlansDrop();
    } );

    var formGroup = document.createElement('div');
    formGroup.setAttribute('class', 'form-group endpoint');

    var select = document.createElement('select');
    select.setAttribute('class', 'form-control');
    select.setAttribute('name', 'endpoint');
    select.setAttribute('style', 'min-width:360px;width:90%;');


    var button = document.createElement('button');
    button.setAttribute('class', 'btn btn-danger')
    button.setAttribute('type', 'button');
    button.setAttribute('style', 'margin:0px 5px;');
    button.addEventListener('click', function(e) {
        formGroup.remove();
        filterVlansDrop();
    });

    var i = document.createElement('i');
    i.setAttribute('class', 'glyphicon glyphicon-remove');

    container.appendChild(formGroup);
    formGroup.appendChild(select);
    formGroup.appendChild(button);
    button.appendChild(i);

    for (var i = 0; i < endpointOptions.length; i++) {
        var opt = document.createElement('option');
        opt.innerHTML = endpointOptions[i];
        opt.setAttribute('value', endpointOptions[i]);
        select.appendChild(opt);
    }
    return select;
}
function intersect_safe(a, b)
{
    var ai=0, bi=0;
    var result = [];

    while( ai < a.length && bi < b.length )
    {
        if      (a[ai] < b[bi] ){ ai++; }
        else if (a[ai] > b[bi] ){ bi++; }
        else /* they're equal */
        {
            result.push(a[ai]);
            ai++;
            bi++;
        }
    }

    return result;
}
function filterVlansDrop() {
    var endpoints = document.forms[1].endpoint;

    var dropd = document.getElementById("vlan_optgroup");
    dropd.innerHTML = '';
    var opt = document.createElement('option');
    opt.innerHTML = "Add and select an endpoint to filter VLANS";
    dropd.appendChild(opt);

    var low   = 1;
    var high  = 0;
    var first_time = 0;

    var vlanIds = [];
    var intermediate= [];
    if(typeof endpoints !== 'undefined') {
        if (endpoints.value === '') {
            var epNames = [];
            for (var i = 0; i < endpoints.length; i++) {
                epNames.push(endpoints[i].value);
            }
            endpoints = epNames;
        } else {
            endpoints = [endpoints.value];
        }

        for (var i = 0; i < endpoints.length; i++) {

            if (endpoints.length != 1) {

                for (var j = 0; j < portTags[endpoints[i]].length; j++) {
                    var parts = portTags[endpoints[i]][j].split("-").map(Number);
                    var low   = parts[0];
                    var high  = parts[0];

                    if (parts.length > 1) {
                        high = parts[1];
                    }
                    for (var k = low; k <= high; k++) {
                        intermediate.push(k);
                    }
                }
                if (first_time == 0 ) {
                    vlanIds = intermediate;
                    first_time = 1;
                } else {
                    intermediate.sort(function(a, b){return a - b});
                    vlanIds.sort(function(a, b){return a - b});
                    vlanIds = intersect_safe(intermediate, vlanIds);
                }

                intermediate = [];

            } else {

                for (var j = 0; j < portTags[endpoints[i]].length; j++) {
                    var parts = portTags[endpoints[i]][j].split("-").map(Number);
                    var low   = parts[0];
                    var high  = parts[0];

                    if (parts.length > 1) {
                        high = parts[1];
                    }
                    for (var k = low; k <= high; k++) {
                        if (vlanIds.includes(k)) {
                            continue;
                        }
                        vlanIds.push(k);
                    }
                }
            }
        }
    } else {

        for (var key in portTags) {
            for (var j = 0; j < portTags[key].length; j++) {
                var parts = portTags[key][j].split("-").map(Number);
                low   = parts[0];
                high  = parts[0];

                if (parts.length > 1) {
                    high = parts[1];
                }

                for (var k = low; k <= high; k++) {
                    if (vlanIds.includes(k)) {
                        continue;
                    }
                    vlanIds.push(k);
                }
            }
        }
    }

    vlanIds.sort(function(a, b){return a - b});
    for (var i = 0; i < vlanIds.length; i++) {
        var opt = document.createElement('option');
        opt.innerHTML = vlanIds[i];
        opt.setAttribute('value', vlanIds[i]);
        if (i == 0 && typeof endpoints !== 'undefined') {
            opt.setAttribute('selected', vlanIds[i]);
        }
        dropd.appendChild(opt);
    }

}

function configureButtons() {
    var createEndpoint = document.getElementById('create_endpoint_button');
    createEndpoint.addEventListener("click", createEndpointSelector, false);

    var create = document.getElementById('create_button');
    create.addEventListener("click", createVlan, false);

    var cancel = document.getElementById('cancel_button');
    cancel.addEventListener("click", cancelVlan, false);
}

function createVlan(e) {
    var cookie = Cookies.getJSON('vce');
    var name = cookie.switch;
    var workgroup = cookie.workgroup;

    var endpoints = document.forms[1].endpoint;

    if(typeof endpoints === 'undefined')
        return displayError('Please select atleast one endpoint');
    if (endpoints.value === '') {
        var epNames = [];
        for (var i = 0; i < endpoints.length; i++) {
            epNames.push(endpoints[i].value);
        }
        endpoints = epNames;
    } else {
        endpoints = [endpoints.value];
    }

    var desc = document.getElementById('description');
    var text = desc.value;

    var vlan = document.getElementById('vlan');
    if (vlan.selectedIndex == 0) {
        return displayError('Please select a VLAN');
    }
    var vlan_id = vlan.options[vlan.selectedIndex].value;

    var url = baseUrl + 'provisioning.cgi?method=add_vlan';
    url += '&workgroup=' + workgroup;
    url += '&description=' + text;
    url += '&switch=' + name;
    url += '&vlan=' + vlan_id;
    url += endpoints.map(function(e) {
        return '&port=' + e;
    }).join('');

    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error_text !== 'undefined') {
                return displayError(data.error_text);
            }
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }
            setDisplayMessage('success', 'Vlan created successfully. '+data.msg);
            window.location.href = 'details.html?tab=vlan';
        });
    });
}

function cancelVlan(e) {
    window.location.href = 'details.html?tab=vlan';
}

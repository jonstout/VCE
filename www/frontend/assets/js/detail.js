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

            console.log("get_workgroup_operational_status");
            console.log(data);

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
                    // vlan.innerHTML = `▲ ${vlans_up} &nbsp;&nbsp; ▼ ${vlans_dn}`;
                    vlan.innerHTML = `Active:${vlans_up} &nbsp;&nbsp; Impacted:${vlans_dn}`;

                    var ports = document.getElementById("switch_ports");
                    var ports_up = switches[i].up_ports;
                    var ports_dn = switches[i].total_ports - switches[i].up_ports;
                    // ports.innerHTML = `▲ ${ports_up} &nbsp;&nbsp; ▼ ${ports_dn}`;
                    ports.innerHTML = `Active:${ports_up} &nbsp;&nbsp; Inactive:${ports_dn}`;
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

    $('#port_select').change(function(e) {
        var form = document.getElementById(e.target.value);

        for (var i = 0; i < form.parentNode.childNodes.length; i++) {
            form.parentNode.childNodes[i].setAttribute('style', 'display: none;');
        }
        form.setAttribute('style', 'display: block;');

        document.getElementById('port_form_container').setAttribute('style', 'display: block;');
    });

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
                if (ports[i].link_up === 1) {
                    status.innerHTML = 'Up';
                } else {
                    status.innerHTML = 'Down';
                }

                if (ports[i].admin_up === 0) {
                    status.innerHTML = 'Disabled';
                }
            }

            $('#port_table').off('click', '.clickable-row');
            $('#port_table').on('click', '.clickable-row', function(e) {
                $(this).addClass('active').siblings().removeClass('active');

                let row = $(this)[0];
                let name = row.id;
                let description = row.childNodes[1].innerHTML;

                var cookie = Cookies.getJSON('vce');
                cookie.port = name;
                Cookies.set('vce', cookie);
                // Uncomment for statistics part
                /* document.getElementById('port_subtab').style.display = 'block';
                var grafana = document.getElementById('grafana-plugin');
                cookie.grafana = grafanaUrl+"var-node="+cookie.switch+"&var-intf="+cookie.port.replace(/ /g,'');
                grafana.src = cookie.grafana;
                Cookies.set('vce', cookie);
                document.getElementById('port_subtab').style.display = 'block';
                */
                document.getElementById('port_select').disabled = false;
                document.getElementById('port_select').selectedIndex = 0;
                document.getElementById('port_form_container').setAttribute('style', 'display: none;');

                // Load commands available for this port
                getPortCommands();
                drawChart();
                document.getElementById('selected_port').innerHTML = `${name} <small>${description}</small>`;
            });
        });
    });
}

// Uncomment for statistics part
/* $('#comm-port-tabs').click(function(e) {
    var cookie = Cookies.getJSON('vce');
    var grafana = document.getElementById('grafana-plugin');
    grafana.src = cookie.grafana;
});*/




function getPortCommands() {
    var cookie = Cookies.getJSON('vce');

    var url = baseUrl + 'access.cgi?method=get_port_commands';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + cookie.switch;
    url += '&port=' + cookie.port;

    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cmds = data.results;

            // Remove commands from dropdown for command population
            document.getElementById("port_show_commands").innerHTML = '';
            document.getElementById("port_action_commands").innerHTML = '';

            var formContainer = document.getElementById("port_form_container");
            formContainer.innerHTML = '';

            for (var i = 0; i < cmds.length; i++) {
                var commandForm = NewCommandForm(cmds[i], function(raw) {
                    var well = document.getElementById("port_response_well");
                    well.innerHTML = "";

                    var pre = document.createElement("pre");
                    pre.innerHTML = raw;
                    well.appendChild(pre);
                });
                formContainer.appendChild(commandForm);

                var opt = document.createElement('option');
                opt.innerHTML = cmds[i].name;
                opt.setAttribute('value', `form-${cmds[i].command_id}`);

                if (cmds[i].operation == "read") {
                    document.getElementById("port_show_commands").appendChild(opt);
                } else {
                    document.getElementById("port_action_commands").appendChild(opt);
                }
            }
        });
    });
}

function configureVLANButtons(e) {
    document.getElementById('add_vlan').onclick = function(e) {
        window.location.href = 'create.html';
    }

    document.getElementById('edit_vlan').onclick = function(e) {
        window.location.href = 'edit.html';
    }

    document.getElementById('delete_vlan').onclick = function(e) {
        var cookie    = Cookies.getJSON('vce');
        var name      = cookie.switch;
        var vlanId    = cookie.selectedVlanId;
        var workgroup = cookie.workgroup;

        var url = baseUrl + 'provisioning.cgi?method=delete_vlan';
        url += '&workgroup=' + workgroup;
        url += '&vlan_id=' + vlanId;
        var vlanName= $('#'+vlanId).contents().first().text();
        if (!confirm(`This action will delete VLAN ${vlanName}.\n\n Do you wish to continue?`)) {
            return 1;
        }

        fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
            response.json().then(function(data) {
                if (typeof data.error !== 'undefined') {
                    setDisplayMessage('error', data.error.msg);
                } else {
                    setDisplayMessage('success', `VLAN ${vlanName} was successfully removed from ${name}.`);
                }

                window.location.href = 'details.html?tab=vlan';
            });
        });
    }
}

function loadVlans() {
    configureVLANButtons(null);

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
            console.log("VLANS:");
            console.log(vlans);
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

            $('#vlan_table').off('click', '.clickable-row');
            $('#vlan_table').on('click', '.clickable-row', function(e) {
                $(this).addClass('active').siblings().removeClass('active');

                let row = $(this)[0];
                let id = row.id;
                let name = row.childNodes[0].innerHTML;
                let description = row.childNodes[1].innerHTML;

                var cookie = Cookies.getJSON('vce');
                cookie.selectedVlanId = id;
                Cookies.set('vce', cookie);

                document.getElementById('edit_vlan').setAttribute('style', 'display: block; margin: 2px;');
                document.getElementById('delete_vlan').setAttribute('style', 'display: block; margin: 2px;');

                document.getElementById('vlan_select').disabled = false;
                document.getElementById('vlan_select').selectedIndex = 0;
                document.getElementById('vlan_form_container').setAttribute('style', 'display: none;');

                getVlanCommands();
                document.getElementById('selected_vlan').innerHTML = `${name} <small>${description}</small>`;
            });
        });
    });
}

function getVlanCommands() {
    var cookie = Cookies.getJSON('vce');

    $('#vlan_select').change(function(e) {
        var form = document.getElementById(e.target.value);

        for (var i = 0; i < form.parentNode.childNodes.length; i++) {
            form.parentNode.childNodes[i].setAttribute('style', 'display: none;');
        }
        form.setAttribute('style', 'display: block;');

        document.getElementById('vlan_form_container').setAttribute('style', 'display: block;');
    });

    var url = baseUrl + 'access.cgi?method=get_vlan_commands';
    url += '&workgroup=' + cookie.workgroup;
    url += '&switch=' + cookie.switch;
    url += '&vlan_id=' + cookie.selectedVlanId;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cmds = data.results;

            // Remove commands from dropdown for command population
            document.getElementById("vlan_show_commands").innerHTML = '';

            var formContainer = document.getElementById("vlan_form_container");
            formContainer.innerHTML = '';

            for (var i = 0; i < cmds.length; i++) {
                var commandForm = NewCommandForm(cmds[i], function(raw) {
                    var well = document.getElementById("vlan_response_well");
                    well.innerHTML = "";

                    var pre = document.createElement("pre");
                    pre.innerHTML = raw;
                    well.appendChild(pre);
                });
                formContainer.appendChild(commandForm);

                var opt = document.createElement('option');
                opt.innerHTML = cmds[i].name;
                opt.setAttribute('value', `form-${cmds[i].command_id}`);

                if (cmds[i].operation == "read") {
                    document.getElementById("vlan_show_commands").appendChild(opt);
                } else {
                    console.log('Could not add command: ' + String(opt));
                }
            }
        });
    });
}

function loadSwitchCommands() {
    var cookie = Cookies.getJSON('vce');

    $('#switch_select').change(function(e) {
        var form = document.getElementById(e.target.value);

        for (var i = 0; i < form.parentNode.childNodes.length; i++) {
            form.parentNode.childNodes[i].setAttribute('style', 'display: none;');
        }
        form.setAttribute('style', 'display: block;');
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
                opt.setAttribute('value', `form-${cmds[i].command_id}`);

                if (cmds[i].operation == "read") {
                    document.getElementById("switch_show_commands").appendChild(opt);
                } else {
                    document.getElementById("switch_action_commands").appendChild(opt);
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

google.charts.load('current', {'packages':['corechart']});

function drawChart() {
    var cookie = Cookies.getJSON('vce');

    let host = cookie.switch;
    let port = cookie.port.replace(' ', '');

    var url = `../influx/query?db=mydb&q=select "time",mean("tx") as "tx" ,mean("rx") as "rx" from "intf" where "name"=$name and time > now()-12h group by time(30m)&params={"name":"${port}"}`;

    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            let c = data.results[0].series[0].values;

            let legend = 'bps';
            let rate_d = 1;
            var max = c.reduce(function(a, b) {
                if (Array.isArray(a)) {
                    return Math.max(Math.round(a[2]), Math.round(b[2]));
                } else {
                    return Math.max(a, Math.round(b[2]));
                }
            });
            if (max > 1000) {
                legend = 'kbps';
                rate_d = 1000;
            }
            if (max > 1000000) {
                legend = 'Mbps';
                rate_d = 1000000;
            }
            if (max > 1000000000) {
                legend = 'Gbps';
                rate_d = 1000000000;
            }
            let d = c.map((v) => {
                v[0] = new Date(v[0]);
                v[1] = v[1]/rate_d;
                v[2] = v[2]/rate_d;
                return v;
            });

            d.unshift(data.results[0].series[0].columns);

            var data = google.visualization.arrayToDataTable(d);
            var options = {
                colors:['#18BC9C','#2C3E50'],
                curveType: 'function',
                legend: { position: 'bottom' },
                vAxes: {
                    0: {title: legend}
                }
            };

            var chart = new google.visualization.LineChart(document.getElementById('curve_chart'));
            chart.draw(data, options);
        });
    });
}

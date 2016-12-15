
function loadWorkgroup() {
    cookie = Cookies.getJSON('vce');
    var workgroupName = cookie.workgroup;
    
    var url = 'https://jonstout-dev.grnoc.iu.edu/vce/api/access.cgi?method=get_workgroup_details';
    url += '&workgroup=' + workgroupName;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var workgroup = data.results[1];
            
            var name = document.getElementById('workgroup_name');
            name.innerHTML = workgroup.name;

            var description = document.getElementById('workgroup_description');
            description.innerHTML = workgroup.description;

            var users = document.getElementById('workgroup_users');
            users.innerHTML = workgroup.users.toString();

            var switches = document.getElementById('workgroup_switches');
            switches.innerHTML = workgroup.switches.length;
        });
    });
}

function loadSwitches() {
    cookie = Cookies.getJSON('vce');
    var workgroupName = cookie.workgroup;
    
    var url = 'https://jonstout-dev.grnoc.iu.edu/vce/api/operational.cgi?method=get_workgroup_operational_status';
    url += '&workgroup=' + workgroupName;
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var switches = data.results[0].workgroups;
            var switchNames = [];
            
            var table = document.getElementById("switch_table");
            table.innerHTML = '';
            
            for (var i = 0; i < switches.length; i++) {
                var row = table.insertRow(0);

                var sw = row.insertCell(0);
                sw.id = switches[i].name;
                sw.innerHTML = switches[i].name;
                switchNames.push(switches[i].name);
                
                var status = row.insertCell(1);
                status.innerHTML = switches[i].status;
                
                var vlan = row.insertCell(2);
                vlan.innerHTML = switches[i].up_vlans.toString() + "/" + switches[i].total_vlans.toString();
                
                var ports = row.insertCell(3);
                ports.innerHTML = switches[i].up_ports.toString() + "/" + switches[i].total_ports.toString();
            }
            
            setHeader(switchNames);
        });
    });
}

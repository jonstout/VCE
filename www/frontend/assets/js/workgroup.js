function selectWorkgroup(e) {
    var selectedWorkgroup = document.getElementById('workgroup_select');
    selectedWorkgroup.innerHTML = e.target.innerHTML + ' ▾';
    
    cookie = Cookies.getJSON('vce');
    cookie.workgroup = e.target.innerHTML;
    Cookies.set('vce', cookie);
    
    loadWorkgroup(e.target.innerHTML);
    loadSwitches(e.target.innerHTML);
}

// Get all workgroups for this user. If the workgroup has not yet been set,
// use the first found.
function loadWorkgroups() {
    var workgroupName;
    
    cookie = Cookies.getJSON('vce');
    if (cookie != undefined) {
        workgroupName = cookie.workgroup;
    }
    
    var url = 'api/access.cgi?method=get_workgroups';
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var workgroups = data.results[0].workgroups;
            
            var selectedWorkgroup = document.getElementById('workgroup_select');
            if (workgroupName === null) {
                workgroupName = workgroups[0];
            }
            selectedWorkgroup.innerHTML = workgroups[0] + ' ▾';
            
            var workgroupList = document.getElementById('workgroup_select_list');
            workgroupList.innerHTML = '';
            for (var i = 0; i < workgroups.length; i++) {
                var li = document.createElement("li");
                li.setAttribute('role', 'presentation');

                var link = document.createElement("a");
                link.innerHTML = workgroups[i];
                link.setAttribute('href', '#');
                link.addEventListener("click", selectWorkgroup, false);

                li.appendChild(link);
                workgroupList.appendChild(li);
            }
            
            cookie.workgroup = workgroupName;
            Cookies.set('vce', cookie);
        });
    });
}

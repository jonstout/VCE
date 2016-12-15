function selectWorkgroup(e) {
    var selectedWorkgroup = document.getElementById('workgroup_select');
    selectedWorkgroup.innerHTML = e.target.innerHTML + ' ▾';
    
    cookie = Cookies.getJSON('vce');
    cookie.workgroup = e.target.innerHTML;
    Cookies.set('vce', cookie);
    
    loadWorkgroup(e.target.innerHTML);
    loadSwitches(e.target.innerHTML);
}

function loadWorkgroups() {
    cookie = Cookies.getJSON('vce');
    var workgroupName = cookie.workgroup;
    
    var url = 'https://jonstout-dev.grnoc.iu.edu/vce/api/access.cgi?method=get_workgroups';
    fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        response.json().then(function(data) {
            var workgroups = data.results[0].workgroups;
            
            var selectedWorkgroup = document.getElementById('workgroup_select');
            if (workgroupName === null || workgroupName === undefined) {
                selectedWorkgroup.innerHTML = workgroups[0] + ' ▾';
            } else {
                selectedWorkgroup.innerHTML = workgroupName;
            }
            
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
        });
    });
}

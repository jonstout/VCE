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
    var url = baseUrl + 'access.cgi?method=get_workgroups';
    return fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        return response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var cookie = Cookies.getJSON('vce');
            var workgroup = cookie.workgroup;

            var workgroups = data.results[0].workgroups;
            if (workgroup === null) {
                    workgroup = workgroups[0];
            } else {
                var workgroupFound = false;

                for (var i = 0; i < workgroups.length; i++) {
                    if (workgroups[i] === workgroup) {
                        workgroupFound = true;
                    }
                }

                if (!workgroupFound) {
                    workgroup = workgroups[0];
                }
            }

            var selectedWorkgroup = document.getElementById('workgroup_select');
            selectedWorkgroup.innerHTML = workgroup + ' ▾';
            
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
            
            cookie.workgroup = workgroup;
            Cookies.set('vce', cookie);

            return Cookies.getJSON('vce');
        });
    });
}

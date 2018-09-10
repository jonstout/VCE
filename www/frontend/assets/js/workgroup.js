function selectWorkgroup(e) {
    var workgroupSelector = document.getElementById('workgroup-selector');
    workgroupSelector.innerHTML = `${e.target.dataset.username} / ${e.target.dataset.workgroup}` + ' ▾';

    cookie = Cookies.getJSON('vce');
    cookie.workgroup = e.target.dataset.workgroup;
    Cookies.set('vce', cookie);

    location.reload();
}

// Get all workgroups for this user. If the workgroup has not yet been set,
// use the first found.
function loadWorkgroups() {
    var url = baseUrl + 'user.cgi?method=get_current';
    return fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
        return response.json().then(function(data) {
            if (typeof data.error !== 'undefined') {
                return displayError(data.error.msg);
            }

            var username = data.results.username;
            var email = data.results.email;
            var name = data.results.fullname;
            var workgroups = data.results.workgroups;

            var cookie = Cookies.getJSON('vce');
            var workgroup = cookie.workgroup;

            if (workgroup === null) {
                workgroup = workgroups[0].name;
            } else {
                var workgroupFound = false;

                for (var i = 0; i < workgroups.length; i++) {
                    if (workgroups[i].name === workgroup) {
                        workgroupFound = true;
                    }
                }

                if (!workgroupFound) {
                    workgroup = workgroups[0].name;
                }
            }

            var workgroupSelector = document.getElementById('workgroup-selector');
            if (workgroupSelector === null) {
                console.log("Couldn't load workgroup selector.");
                cookie.workgroup = workgroup;
                Cookies.set('vce', cookie);
                return Cookies.getJSON('vce');
            }
            workgroupSelector.innerHTML = `${username} / ${workgroup}` + ' ▾';

            if (workgroup === 'admin') {
                document.getElementById('admin-button').style.display = 'block';
            }

            var workgroupSelectorOptions = document.getElementById('workgroup-selector-options');
            workgroupSelectorOptions.innerHTML = '';
            workgroupSelectorOptions.setAttribute('style', 'margin-top: 42px');

            var content = `<b style="color: #282D32">${username}</b><br/>`;
            if (name != "") content += `<span style="color: #282D32">${name}</span><br/>`;
            if (email != "") content += `<span style="color: #282D32">${email}</span>`;
            content += `<hr style="margin: 8px 0 8px 0"/>`;

            var li = document.createElement('li');
            li.setAttribute('role', 'presentation');
            li.setAttribute('style', 'padding: 0px 8px 0px 8px');
            li.innerHTML = content;
            workgroupSelectorOptions.appendChild(li);

            for (var i = 0; i < workgroups.length; i++) {
                var li = document.createElement("li");
                li.setAttribute('role', 'presentation');

                var link = document.createElement("a");
                link.innerHTML = workgroups[i].name;
                link.setAttribute('href', '#');
                link.dataset.workgroup = workgroups[i].name;
                link.dataset.username = username;
                link.addEventListener("click", selectWorkgroup, false);

                li.appendChild(link);
                workgroupSelectorOptions.appendChild(li);
            }
            
            cookie.workgroup = workgroup;
            Cookies.set('vce', cookie);
            return Cookies.getJSON('vce');
        });
    });
}

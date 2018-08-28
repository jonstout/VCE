window.onload = init;

async function init() {
    await getWorkgroups().then(function(workgroups) {
        renderWorkgroupList(workgroups);
    });
};

function addSwitch(form) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let post = async function(data) {
        try {
            const url = '../api/workgroup.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `modify_workgroups.html?workgroup_id=${obj.results[0].id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    form.workgroup.value = workgroup;

    let data = new FormData(form);
    post(data);
    return false;
}

async function getWorkgroups() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_workgroups&workgroup=${workgroup}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) {
            console.log(data.error_text);
            return [];
        }
        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderWorkgroupList(workgroups) {
    let list = document.querySelector('#aside-list');
    let items = '';

    workgroups.forEach(function(workgroup) {
        items += `<li><a href="modify_workgroups.html?workgroup_id=${workgroup.id}">${workgroup.name}</a></li>`;
    });

    list.innerHTML = items;
}

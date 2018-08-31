window.onload = init;

async function init() {
    getUsers().then(function(users) {
        renderUserList(users);
    });

    let params = new URLSearchParams(location.search);
    let user_id = params.get('user_id');

     getUser(user_id).then(function(user) {
         renderUser(user);
     });

     getWorkgroups(user_id).then(function(workgroups) {
         renderWorkgroups(workgroups);
     });

    document.querySelector('#detail-tab').addEventListener('click', function(e) {
        document.querySelector('#workgroup-tab').classList.remove("is-active");
        document.querySelector('#workgroup-tab-content').style.display = 'none';
        document.querySelector('#detail-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });
    document.querySelector('#workgroup-tab').addEventListener('click', function(e) {
        document.querySelector('#detail-tab').classList.remove("is-active");
        document.querySelector('#detail-tab-content').style.display = 'none';
        document.querySelector('#workgroup-tab-content').style.display = 'block';
        e.target.parentElement.classList.add("is-active");
    });
};

function modifyUser(form) {
    let func = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let workgroup = cookie.workgroup;

        let params = new URLSearchParams(location.search);
        let id = params.get('user_id');

        data.set('method', 'modify_user');
        data.set('user_id', id);
        data.set('workgroup', workgroup);

        try {
            const url = '../api/user.cgi';
            const resp = await fetch(url, {method: 'post', credentials: 'include', body: data});
            const obj = await resp.json();

            if ('error_text' in obj) throw obj.error_text;

            window.location.href = `modify_users.html?user_id=${id}`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    func(new FormData(form));
    return false;
}

function deleteSwitch() {
    let ok = confirm('Are you sure you wish to delete this device?');
    if (!ok) {
        return false;
    }

    let del = async function(data) {
        let cookie = Cookies.getJSON('vce');
        let wg = cookie.workgroup;

        let id = data.get('id');
        let method = 'delete_switch';

        try {
            const url = `../api/switch.cgi?method=${method}&id=${id}&workgroup=${wg}`;
            const resp = await fetch(url, {method: 'get', credentials: 'include'});
            const obj = await resp.json();

            if ('error_text' in obj) {
                console.log(obj.error_text);
                return false;
            }
            window.location.href = `switches.html`;
        } catch (error) {
            console.log(error);
            return false;
        }
    };

    let form = document.forms['modify-switch'];
    let data = new FormData(form);
    del(data);
    return false;
}

async function getUser(user_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `user.cgi?method=get_users&workgroup=${workgroup}&user_id=${user_id}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) throw data.error_text;
        return data.results[0];
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderUser(user) {
    let form = document.forms['modify-user'];
    form.elements['username'].value = user.username;
    form.elements['fullname'].value = user.fullname;
    form.elements['email'].value = user.email;
}

async function getUsers() {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `user.cgi?method=get_users&workgroup=${workgroup}`;
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

async function renderUserList(users) {
    let list = document.querySelector('#aside-list');
    let items = '';

    users.forEach(function(user) {
        items += `<li><a href="modify_users.html?user_id=${user.id}">${user.username}</a></li>`;
    });

    list.innerHTML = items;
}

async function getWorkgroups(user_id) {
    let cookie = Cookies.getJSON('vce');
    let workgroup = cookie.workgroup;

    let url = '../' + baseUrl + `workgroup.cgi?method=get_user_workgroups&workgroup=${workgroup}&user_id=${user_id}`;
    let response = await fetch(url, {method: 'get', credentials: 'include'});

    try {
        let data = await response.json();
        if ('error_text' in data) throw data.error_text;
        return data.results;
    } catch(error) {
        console.log(error);
        return null;
    }
}

async function renderWorkgroups(workgroups) {
    let rows = '';

    workgroups.forEach(function(wg) {
        let row = `
<tr>
  <td>${wg.name}</td>
  <td>${wg.description}</td>
  <td>${wg.role}</td>
</tr>`;
        rows += row;
    });

    let tbody = document.querySelector('#user-workgroup-list');
    tbody.innerHTML = rows;
}

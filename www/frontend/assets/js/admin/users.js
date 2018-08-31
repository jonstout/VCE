window.onload = init;

async function init() {
    getUsers().then(function(users) {
        renderUserList(users);
    });
};

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

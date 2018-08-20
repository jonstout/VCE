/* NewCommandForm
 * details: An array of parameter descriptions
 * 
 * Returns a new form containing input fields for the parameters
 * described in details. Parameters with the following names are
 * assumed to be stored in the 'vce' cookie, are hidden from the
 * user, and have their submitted values overwritten by the
 * cookie values.
 *
 * - workgroup
 * - switch
 * - port
 * - vlan_id
 *
 * After submit, the results of a successful request will be
 * added to a pre tag, and placed in #result_text.
 */
function NewCommandForm(details, reponseFunc) {
    var cookie = Cookies.getJSON('vce');

    // Create form and its input fields
    var form = document.createElement("form");
    form.setAttribute("id", `form-${details.command_id}`);
    form.style.display = "none";

    for (var i = 0; i < details.parameters.length; i++) {
        var param = details.parameters[i];

        var group = document.createElement("div");
        group.setAttribute("class", "form-group");
        
        var input = null;
        var label = document.createElement("label");
        
        if (param.type == "select") {
            input = document.createElement("select");
            
            for (var j = 0; j < param.options.length; j++) {
                var opt = document.createElement("option");
                opt.innerHTML = param.options[j];
                
                input.appendChild(opt);
            }
        } else {
            input = document.createElement("input");
            input.setAttribute("type", "text");
        }

        input.setAttribute("name", param.name);
        input.setAttribute("class", "form-control");
        
        label.setAttribute("class", "control-label");
        label.innerHTML = param.name;
        
        // Create hidden forms for data stored in cookie
        if (param.name == "workgroup" || param.name == "switch" || param.name == "port" || param.name == "vlan_id") {
            group.style.display = "none";
        }

        group.appendChild(label);
        group.appendChild(input);
        form.appendChild(group);
    }
    
    // Create submit button
    var group = document.createElement("div");
    group.setAttribute("class", "form-group");

    var input = document.createElement("input");
    input.setAttribute("type", "button");
    input.setAttribute("value", "Submit");
    input.setAttribute("name", `submit-${details.command_id}`);
    input.setAttribute("class", "form-control");
    
    group.appendChild(input);
    form.appendChild(group);

    form.setAttribute("method", "get");
    form.setAttribute("class", "form-horizontal");
    
    // Setup onsubmit callback    
    input.addEventListener("click", function(e) {
        console.log(e.target);
        var cookie = Cookies.getJSON('vce');
        var url = baseUrl + 'command.cgi?method=' + details.method_name.replace(/ /g,'');

        for (var i = 0; i < e.target.form.length; i++) {
            var name  = e.target.form[i].name;
            var value = e.target.form[i].value;
            
            // Handle data saved in cookies.
            if (name == "workgroup") {
                value = cookie.workgroup;
            } else if (name == "switch") {
                value = cookie.switch;
            } else if (name == "port") {
                value = cookie.port;
            } else if (name == "vlan_id") {
                value = cookie.selectedVlanId;
            }
            
            url += "&" + name + "=" + value;
        }
        console.log(url);
        
        fetch(url, {method: 'get', credentials: 'include'}).then(function(response) {
            response.json().then(function(data) {
                if (typeof data.error !== 'undefined') {
                    return displayError(data.error.msg);
                }

                console.log(data);
                reponseFunc(data.raw);
            });
        });
    });

    return form;
}

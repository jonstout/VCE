# VCE
Virtual Customer Equipment

## Installation
The following installation assumes a Centos7 machine. It also assumes that rabbitmq is installed and running. See [here](https://www.rabbitmq.com/install-rpm.html) for RabbitMQ installation instructions.

1. Edit `/etc/yum.repos.d/grnoc-public.repo` to install the GlobalNOC's Centos7 RPM repository.
```
[grnoc-public]
name=GlobalNOC Public el7 Packages - $basearch
baseurl=https://repo-public.grnoc.iu.edu/repo/7/$basearch
enabled=1
gpgcheck=1
gpgkey=https://repo-public.grnoc.iu.edu/repo/RPM-GPG-KEY-GRNOC7
```
2. Execute `sudo yum makecache`
3. Execute `sudo yum install vce`

Assuming the previous steps finished successfully, VCE is now installed. Continue to the configuration portion of this document to configure network device credentials, rabbitmq credentials, and user permissions. Once complete start vce using `systemctl`.

```
sudo systemctl start vce
```

## Configuration

### Access Policy and CLI Commands

VCE's configuration file is located at `/etc/vce/access_policy.xml`. This file is used to configure the following:

* CLI commands
* Network device credentials
* Per-port VLAN permissions
* RabbitMQ credentials
* Workgroups

#### CLI Commands
To expose a command to the users, define a command block under the `<port>`, `<system>`, or `<vlan>` tag. Commands used under `<port>` can use the `port` template variable which inserts the port name of the selected interface. Commands used under `<vlan>` can use the `vlan_id` template variable which inserts the VLAN of the selected vlan. Custom parameters may also be defined.

```xml
<command method_name='show_interface' name='show interface' type='show' interaction='cli' description='show all interfaces'>
  <cmd>show interface [% port %]</cmd>
</command>
```

In order to execute some commands, the user must enter into a specific device context. Use the `context` parameter to enter into the correct context before executing the command.

```xml
<command method_name='set_port_descr' name='set port descr' type='action' context='interface [% port %]' input='descr' interaction='cli' configure='true' description='changes the description on a port'>
  <cmd>port-name [% description %]</cmd>
  <parameter name='description' pattern='(.*)' description='the description to set for the port' type='text' />
</command>
```

#### Network device credentials
Setup network device credentials under `<switch>`. **Important:** Each device must expose a port for SSH and allow for netconf connections on port `830`.

```xml
<switch name="MLXe" ip="192.168.1.10" ssh_port="22" username="admin" password="admin"
        vendor="Brocade" model="MLXe" version="5.8.0" description="brocade">
```

#### Per-port VLAN permissions
To expose a port to the users, define a port block under the `<switch>` tag. The port owner will have absolute control over the interface. Each `<tags>` will define the VLAN range that a workgroup may provision.

```xml
<port name="ethernet 4/1" owner="admin">
  <tags start="1" end="100" workgroup="admin"/>
  <tags start="101" end="200" workgroup="basic"/>
</port>
```

#### RabbitMQ credentials
```xml
<rabbit host="localhost" port="5672" user="guest" pass="guest" />
```

#### Workgroups
To define a workgroup, create a workgroup block. Use `admin="1"` to define the system admin workgroup.

```xml
<workgroup name="admin" admin="1" description="admin workgroup">
  <user id="user-1" />
  <user id="user-2" />
</workgroup>
```
### Frontend Assets
The frontend is installed to `/usr/share/vce/www/`. Below is an Apache configuration that may be used to host the frontend and the API.

```
Alias /vce     /usr/share/vce/www/frontend
Alias /vce/api /usr/share/vce/www/api

<Location /vce>
  AuthType Basic
  AuthName "VCE"
  AuthUserFile /usr/share/vce/www/.htpasswd
  Require valid-user
  SSLRequireSSL

  Order allow,deny
  Allow from all
  Options +ExecCGI
  DirectoryIndex index.html
</Location>

<Location /vce/api>
  AuthType Basic
  AuthName "VCE"
  AuthUserFile /usr/share/vce/www/.htpasswd
  Require valid-user
  SSLRequireSSL

  Order allow,deny
  Allow from all
  AddHandler cgi-script .cgi
  Options +ExecCGI
</Location>
```

### Users
Users are managed via htpasswd file. Create the password file `/usr/share/vce/www/.htpasswd` and first user with the following command. See the htpasswd [documentation](https://httpd.apache.org/docs/current/programs/htpasswd.html) for more information.

```
htpasswd -c /usr/share/vce/www/.htpasswd jane
```

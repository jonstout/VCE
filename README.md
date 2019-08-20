# VCE
Virtual Customer Equipment

## Installation
The following installation assumes a Centos7 machine. It also assumes that rabbitmq is installed and running. See [here](https://www.rabbitmq.com/install-rpm.html) for RabbitMQ installation instructions.

### New installations
Requires VCE, SIMP, TSDS, and Grafana.

#### VCE
1. Edit `/etc/yum.repos.d/grnoc-public.repo` to install the GlobalNOC's Centos7 RPM repository.
    ```
    [grnoc-public]
    name=GlobalNOC Public el7 Packages - $basearch
    baseurl=https://repo-public.grnoc.iu.edu/repo/7/$basearch
    enabled=1
    gpgcheck=1
    gpgkey=https://repo-public.grnoc.iu.edu/repo/RPM-GPG-KEY-GRNOC7
    ```
2. Update your local RPM cache: `sudo yum makecache`
3. Install additional RPM repositories: `sudo yum install globalnoc-grafana`
4. Install VCE: `sudo yum install vce`
5. Ensure VCE Database is fully updated: `sudo perl /usr/bin/vce-update-db`
6. Setup the web credentials of the VCE **admin** user: `sudo htpasswd -c /usr/share/vce/www/.htpasswd admin`
6. Configure your network devices login credentials in: `/etc/vce/password.json`
    ```
    {
      "hostname1": { "username": "username", "password": "password" },
      "hostname2": { "username": "username", "password": "password" },
      ...
    }
    ```
    _Note: You'll need to restart vce whenever this file is updated._
7. Start VCE: `sudo systemctl start vce`
8. Navigate to `http://hostname/vce/admin/switches.html` and finish configuring your network devices.

#### SIMP
SIMP is an SNMP poller which is used to collect network statistics from devices controlled by VCE.

1. Ensure prerequiste SIMP components are running: `sudo systemctl restart rabbitmq-server redis`
2. The SIMP packages were installed along with VCE. Complete configuration of these packages as described [here](https://github.com/GlobalNOC/VCE/wiki/Statistics).
3. Ensure SIMP components are running: `sudo systemctl restart simp-poller simp-data simp-comp simp-tsds`

#### TSDS
TSDS is a timeseries database which will persist collected statistics to disk. This databse may be used for any type of timeseries data. **As the TSDS installation is somewhat complex, please be sure to follow the provided instructions carefully.**

1. Install the TSDS package: `sudo yum install grnoc-tsds-services`
2. Begin configuration the TSDS installation using the following command: `sudo /usr/bin/tsds_setup.pl`.
3. When asked for number of config servers and shards, enter: `1`
4. You will be asked to provide a password for the `root` mongodb user, enter any password: `...`
5. You will be asked to provide a password for the `tsds_ro` mongodb user, enter any password: `...`
6. You will be asked to provide a password for the `tsds_rw` mongodb user, enter any password: `...`
7. It will then initialize the mongo database with necessatry databases and collections. Please enter `y` when asked 'Are you sure?'

#### Grafana Setup
Grafana provides network statistic graphs.

1. **Grafana configuration:** The grafana runs on localhost and need not be directly access by unauthorized user. So in order to make sure only vce users can access grafana, edit `/etc/grafana/grafana.ini` and perform below steps:

      * **Note**: Make sure below changes do not start with ';'
      * In \[server\], update the following:
      
            protocol = http
            root_url = http://localhost/grafana
            
      * In \[auth.proxy\], update the following:
            
            enabled = true
            header_name = X-WEBAUTH-USER
            header_property = username
            auto_sign_up = true
      * In \[security\], update the following
            
            allow_embedding = true


2. Assuming the previous steps finished successfully, VCE and Grafana is now installed. Continue to the configuration portion of this document to configure network device credentials, rabbitmq credentials, and user permissions. Once complete, execute the below given commands.
    ```
    sudo systemctl daemon-reload;
    sudo systemctl restart rabbitmq-server;
    sudo systemctl restart redis;
    sudo systemctl restart vce;
    sudo systemctl restart httpd;
    sudo systemctl restart simp-data;
    sudo systemctl restart simp-comp;
    sudo systemctl restart simp-poller;
    sudo systemctl restart mongod-config1;
    sudo systemctl restart mongod-shard1;
    sudo systemctl restart mongos;
    sudo systemctl restart simp-tsds;
    sudo systemctl restart memcached;
    sudo systemctl restart searchd;
    sudo systemctl restart tsds_writer;
    sudo systemctl restart grafana-server;
    ```
3. Visit `https://<hostname>/grafana/` and login grafana with the web credentials of the VCE **admin** user.
4. Set URL to `http://<hostname>/tsds/services/`
5. Check Basic Auth
6. Check Skip TLS Verify
7. Under Basic Auth Details, enter the web credentials of the VCE **admin** user and click Save & Test.
8. Click **'+'** on the left bar and select 'import' to import the dashboard with graph configurations.
9. Copy and paste `/etc/vce/grafana-dashboard.json` or [grafana-dashboard.json](https://raw.githubusercontent.com/GlobalNOC/VCE/master/etc/grafana-dashboard.json) into the JSON textarea and click Load.

### Upgrading to a newer version

0. Execute `sudo systemctl stop httpd`
1. Execute `sudo systemctl stop vce`


Ensure that `/etc/vce/access_policy.xml` contains the following
`network_model` tag. Verify the path is set to
`/var/lib/vce/database.sqlite`. An example config can be
found
[here](https://github.com/GlobalNOC/VCE/blob/master/etc/access_policy.xml#L3).

```
<network_model path="/var/lib/vce/database.sqlite"/>
```

0. Execute `sudo yum install globalnoc-grafana`
1. Execute `sudo yum install vce`
2. Execute `sudo /bin/vce-update-db`

**NOTE**: Make sure that you have gone through **Grafana Setup** steps in the installation section. If **yes**, please proceed with step 3.

3. Execute `sudo systemctl restart vce`
4. Execute `sudo systemctl restart httpd`


## Configuration

### Access Policy

VCE's configuration file is located at `/etc/vce/access_policy.xml`. This file is used to configure the following:

* RabbitMQ credentials
```xml
<rabbit host="localhost" port="5672" user="guest" pass="guest" />
```
### Final snapshot of access_policy.xml
```xml
<accessPolicy>
  <rabbit host="localhost" port="5672" user="guest" pass="guest"/>
  <network_model path="/var/lib/vce/database.sqlite"/>
</accessPolicy>
```

#### Validate configuration
To quickly verify that the configuration is valid use the `vce-run-check` command.

```
/usr/bin/vce-run-check --config /etc/vce/access_policy.xml
```

### Frontend Assets
The frontend is installed to `/usr/share/vce/www/`. Below is an Apache configuration that may be used to host the frontend and the API.

```
Alias /vce/api /usr/share/vce/www/api
Alias /vce     /usr/share/vce/www/frontend

ProxyPass        /grafana http://localhost:3000
ProxyPassReverse /grafana http://localhost:3000
RequestHeader unset Authorization
<Location /grafana>

  AuthType Basic
  AuthName GrafanaAuthProxy
  AuthBasicProvider file
  AuthUserFile /usr/share/vce/www/.htpasswd
  Require valid-user

  RewriteEngine On
  RewriteRule .* - [E=PROXY_USER:%{LA-U:REMOTE_USER},NS]
  RequestHeader set X-WEBAUTH-USER "%{PROXY_USER}e"
  Order allow,deny
  Allow from all
</Location>

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
Users are managed via htpasswd file. Add them using the below command. Create the password file `/usr/share/vce/www/.htpasswd` and first user using the `-c` flag; If the file has already been created do **not** specify this flag. See the htpasswd [documentation](https://httpd.apache.org/docs/current/programs/htpasswd.html) for more information.

```
htpasswd /usr/share/vce/www/.htpasswd user
```

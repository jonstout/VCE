# VCE
Virtual Customer Equipment

## Installation
The following installation assumes a Centos7 machine. It also assumes that rabbitmq is installed and running. See [here](https://www.rabbitmq.com/install-rpm.html) for RabbitMQ installation instructions.

### New installations

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
2. Execute `sudo yum makecache`
3. Execute `sudo yum install globalnoc-grafana`
4. Execute `sudo yum install vce`

Once the VCE is installed, we need to install the grafana which will render the Statistics Graph.

#### Grafana Setup

1. Execute `sudo systemctl restart rabbitmq-server`
2. Execute `sudo systemctl restart redis`
3. Please go to [Statistics](https://github.com/GlobalNOC/VCE/wiki/Statistics) page and perform all the necessary steps.
4. Assuming that you have performed all steps on [Statistics](https://github.com/GlobalNOC/VCE/wiki/Statistics) page, let us now install tsds-services.

    * Execute `sudo yum install grnoc-tsds-services`

    * **The below steps are for setting up the environment for data collection and requires user input. Please follow all the instructions carefully.** 

    * Execute `sudo /usr/bin/tsds_setup.pl`.

        * When asked for number of config server and shard, please enter 1. This will setup mongodb and the shard for data collection.

        * Once the mongodb environment is setup, it will ask for password for the root user. Please enter the appropriate password.

        * It will ask the password for the tsds read-only user. Please enter the appropriate password.

        * It will ask the password for the tsds read-write user. Please enter the appropriate password.

        * It will then initialize the mongo database with necessatry databases and collections. Please enter 'y' when asked 'Are you sure?'

    * On successful completion of the above step, edit `/etc/simp/simp-tsds.xml` and change the tsds usrl to `http://<hostname>/tsds/services/push.cgi` along with tsds user and password.

Assuming the previous steps finished successfully, VCE and Grafana is now installed. Continue to the configuration portion of this document to configure network device credentials, rabbitmq credentials, and user permissions. Once complete, execute the below given commands.
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
5. The following step is for setting up the grafana dashboard which renders the Statistics chart.

    * Visit `http://<hostname>:3000/` and login grafana with default credentials.

    * Setup the tsds datasource according to configuration section [here](https://globalnoc.github.io/tsds-grafana/)

    * Once the data source is created, click **'+'** on the left bar and select 'import' to import the dashboard with graph configurations.

    * Upload `/etc/vce/grafana-dashboard.json` via upload option or copy and paste the file contents in the paste json textarea, and save the page.

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
htpasswd -c /usr/share/vce/www/.htpasswd admin
```

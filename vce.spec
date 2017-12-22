Summary: Virtual Customer Equipment
Name: vce
Version: 0.2.3
Release: 1%{?dist}
License: Apache
Group: GRNOC
URL: http://globalnoc.iu.edu
Source: %{name}-%{version}.tar.gz

BuildRequires: perl
BuildRequires: perl-AnyEvent-HTTP-LWP-UserAgent
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires(pre): /usr/sbin/useradd, /usr/bin/getent

BuildRequires: httpd-devel
BuildRequires: mod_perl-devel
Requires: perl-Devel-Cover
Requires: perl-GRNOC-CLI
Requires: perl-GRNOC-Comm
Requires: perl-GRNOC-Config
Requires: perl-GRNOC-Log
Requires: perl-GRNOC-NetConf <= 2.0
Requires: perl-GRNOC-RabbitMQ <= 2.0
Requires: perl-GRNOC-WebService-Client
Requires: perl-Moo
Requires: perl-Parallel-ForkManager
Requires: perl-Test-Deep
Requires: perl-Type-Tiny
Requires: rabbitmq-server
Requires: httpd

%description
Installs VCE and its prerequisites.

%prep
%setup -q -n vce-%{version}

%build
%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
make

%pre
/usr/bin/getent group vce || /usr/sbin/groupadd -r vce
/usr/bin/getent passwd vce || /usr/sbin/useradd -r -s /sbin/nologin -g vce vce
/usr/sbin/usermod -a -G vce apache

%install
rm -rf $RPM_BUILDR_ROOT

# Perl
%{__install} -d -p %{buildroot}%{perl_vendorlib}/VCE/Services
%{__install} -d -p %{buildroot}%{perl_vendorlib}/VCE/Device/Brocade/MLXe

%{__install} lib/VCE.pm %{buildroot}%{perl_vendorlib}/VCE.pm
%{__install} lib/VCE/Access.pm %{buildroot}%{perl_vendorlib}/VCE/Access.pm
%{__install} lib/VCE/Device.pm %{buildroot}%{perl_vendorlib}/VCE/Device.pm
%{__install} lib/VCE/NetworkModel.pm %{buildroot}%{perl_vendorlib}/VCE/NetworkModel.pm
%{__install} lib/VCE/Switch.pm %{buildroot}%{perl_vendorlib}/VCE/Switch.pm
%{__install} lib/VCE/Services/Access.pm %{buildroot}%{perl_vendorlib}/VCE/Services/Access.pm
%{__install} lib/VCE/Services/Operational.pm %{buildroot}%{perl_vendorlib}/VCE/Services/Operational.pm
%{__install} lib/VCE/Services/Provisioning.pm %{buildroot}%{perl_vendorlib}/VCE/Services/Provisioning.pm
%{__install} lib/VCE/Services/Switch.pm %{buildroot}%{perl_vendorlib}/VCE/Services/Switch.pm
%{__install} lib/VCE/Device/Brocade/MLXe/5_8_0.pm %{buildroot}%{perl_vendorlib}/VCE/Device/Brocade/MLXe/5_8_0.pm

# Web
%{__install} -d -p %{buildroot}%{_datadir}/vce/www/api
%{__install} -d -p %{buildroot}%{_datadir}/vce/www/frontend

%{__install} www/services/access.cgi %{buildroot}%{_datadir}/vce/www/api
%{__install} www/services/operational.cgi %{buildroot}%{_datadir}/vce/www/api
%{__install} www/services/provisioning.cgi %{buildroot}%{_datadir}/vce/www/api
%{__install} www/services/switch.cgi %{buildroot}%{_datadir}/vce/www/api

cp -ar www/frontend/* %{buildroot}%{_datadir}/vce/www/frontend

# Executables
%{__install} -d -p %{buildroot}%{_bindir}

%{__install} -m 544 bin/vce.pl %{buildroot}%{_bindir}/vce


# Init Scripts
%{__install} -d -p %{buildroot}%{_initddir}
%{__install} -d -p %{buildroot}/usr/lib/systemd/scripts
%{__install} -d -p %{buildroot}/etc/systemd/system
%{__install} -m 544 etc/vce.init %{buildroot}/usr/lib/systemd/scripts/vce
%{__install} -m 544 etc/vce.systemd %{buildroot}/etc/systemd/system/vce.service

# Configuration Files
%{__install} -d -p %{buildroot}%{_sysconfdir}/httpd/conf.d
%{__install} -d -p %{buildroot}%{_sysconfdir}/vce
%{__install} -d -p %{buildroot}%{_var}/run/vce

%{__install} etc/apache-vce.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/vce.conf
%{__install} etc/access_policy.xml %{buildroot}%{_sysconfdir}/vce/access_policy.xml
%{__install} etc/password.json %{buildroot}%{_sysconfdir}/vce/password.json
%{__install} etc/config.xsd %{buildroot}%{_sysconfdir}/vce/config.xsd
%{__install} etc/apache_logging.conf %{buildroot}%{_sysconfdir}/vce/apache_logging.conf
%{__install} etc/logging.conf %{buildroot}%{_sysconfdir}/vce/logging.conf

%{__install} etc/network_model.json %{buildroot}%{_var}/run/vce/network_model.json

# Final Step
%{_fixperms} $RPM_BUILD_ROOT/*

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{perl_vendorlib}/VCE.pm
%{perl_vendorlib}/VCE/Access.pm
%{perl_vendorlib}/VCE/Device.pm
%{perl_vendorlib}/VCE/NetworkModel.pm
%{perl_vendorlib}/VCE/Switch.pm
%{perl_vendorlib}/VCE/Services/Access.pm
%{perl_vendorlib}/VCE/Services/Operational.pm
%{perl_vendorlib}/VCE/Services/Provisioning.pm
%{perl_vendorlib}/VCE/Services/Switch.pm
%{perl_vendorlib}/VCE/Device/Brocade/MLXe/5_8_0.pm

%{_datadir}/vce/www/api/access.cgi
%{_datadir}/vce/www/api/operational.cgi
%{_datadir}/vce/www/api/provisioning.cgi
%{_datadir}/vce/www/api/switch.cgi
%{_datadir}/vce/www/frontend/

%{_bindir}/vce

/etc/systemd/system/vce.service
/usr/lib/systemd/scripts/vce

%{_sysconfdir}/vce/config.xsd

%config(noreplace) %{_sysconfdir}/httpd/conf.d/vce.conf
%config(noreplace) %{_sysconfdir}/vce/access_policy.xml
%config(noreplace) %attr(600,vce,vce) %{_sysconfdir}/vce/password.json
%config(noreplace) %{_sysconfdir}/vce/apache_logging.conf
%config(noreplace) %{_sysconfdir}/vce/logging.conf

%config(noreplace) %attr(664,vce,vce) %{_var}/run/vce/network_model.json

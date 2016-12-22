Summary: Virtual Customer Equipment
Name: vce
Version: 0.1.0
Release: 1%{?dist}
License: Apache
Group: GRNOC
URL: http://globalnoc.iu.edu
Source: %{name}-%{version}.tar.gz

BuildRequires: perl
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires: perl-Apache-Test
Requires: perl-Devel-Cover
Requires: perl-GRNOC-Comm
Requires: perl-GRNOC-Config
Requires: perl-GRNOC-Log
Requires: perl-GRNOC-NetConf <= 2.0
Requires: perl-GRNOC-RabbitMQ <= 2.0
Requires: perl-GRNOC-WebService-Client
Requires: perl-Moo
Requires: perl-Test-Deep

%description
Installs VCE and its prerequisites.

%prep
%setup -q -n vce-%{version}

%build
%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
make

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

%{__install} bin/vce.pl %{buildroot}%{_bindir}
%{__install} bin/vce_switch.pl %{buildroot}%{_bindir}

%{_fixperms} $RPM_BUILD_ROOT/*

# %check
# make test

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644, root, root, -)

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

%{_bindir}/vce.pl
%{_bindir}/vce_switch.pl

%changelog

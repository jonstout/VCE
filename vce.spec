Summary: Virtual Customer Equipment
Name: vce
Version: 0.1.0
Release: 1%{?dist}
License: Apache
Group: GRNOC
URL: http://globalnoc.iu.edu
Source: %{name}-%{version}.tar.gz

BuildRequires: perl
#BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires: perl-GRNOC-NetConf <= 2.0
#Requires: perl-GRNOC-RabbitMQ <= 2.0

%description
Installs VCE and its prerequisites.

#%build
#%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
#make

#%install
#rm -rf $RPM_BUILDR_ROOT

# %{_fixperms} $RPM_BUILD_ROOT/*

# %check
# make test

# %clean
# rm -rf $RPM_BUILD_ROOT

# %files
# %defattr(644, root, root, -)
# %{perl_vendorlib}/VCE.pm
# %{perl_vendorlib}/VCE/Access.pm
# %{perl_vendorlib}/VCE/Device.pm
# %{perl_vendorlib}/VCE/NetworkModel.pm
# %{perl_vendorlib}/VCE/Switch.pm
# %{perl_vendorlib}/VCE/Services/Access.pm
# %{perl_vendorlib}/VCE/Services/Operational.pm
# %{perl_vendorlib}/VCE/Services/Provisioning.pm
# %{perl_vendorlib}/VCE/Services/Switch.pm
# %{perl_vendorlib}/VCE/Device/Brocade/MLXe/5_8_0.pm

# %changelog

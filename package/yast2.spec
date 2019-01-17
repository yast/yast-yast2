#
# spec file for package yast2
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2
Version:        4.1.53
Release:        0
Summary:        YaST2 - Main Package
License:        GPL-2.0-only
Group:          System/YaST
Url:            https://github.com/yast/yast-yast2
Source0:        %{name}-%{version}.tar.bz2
Source1:        yast2-rpmlintrc
# for symlinking yardoc duplicates
BuildRequires:  fdupes
# Needed for tests
BuildRequires:  grep
BuildRequires:  perl-XML-Writer
# for defining abstract methods in libraries
BuildRequires:  rubygem(%{rb_default_ruby_abi}:abstract_method)
# for file access using augeas
BuildRequires:  rubygem(%{rb_default_ruby_abi}:cfa)
# for running scripts
BuildRequires:  update-desktop-files
BuildRequires:  rubygem(%{rb_default_ruby_abi}:cheetah)
# For running RSpec tests during build
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
# For converting to/from punycode strings
BuildRequires:  rubygem(%{rb_default_ruby_abi}:simpleidn)
# Needed already in build time
BuildRequires:  yast2-core >= 2.18.12
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-pkg-bindings >= 2.20.3
# To have Yast::WFM.scr_root
BuildRequires:  yast2-ruby-bindings >= 3.2.8
BuildRequires:  yast2-testsuite
# UI::.SetApplicationTitle
BuildRequires:  yast2-ycp-ui-bindings >= 3.2.0
# for the PackageExtractor tests, just make sure they are present,
# these should be installed in the default build anyway
BuildRequires:  cpio
BuildRequires:  rpm

# for ag_tty (/bin/stty)
# for /usr/bin/md5sum
Requires:       coreutils
# for GPG.ycp
Requires:       gpg2
# for ag_anyxml
Requires:       perl-XML-Simple
# for defining abstract methods in libraries
Requires:       rubygem(%{rb_default_ruby_abi}:abstract_method)
# for file access using augeas
Requires:       rubygem(%{rb_default_ruby_abi}:cfa)
# For converting to/from punycode strings
Requires:       rubygem(%{rb_default_ruby_abi}:simpleidn)
Requires:       sysconfig >= 0.80.0
# for running scripts
Requires:       rubygem(%{rb_default_ruby_abi}:cheetah)
# ag_ini section_private
# ag_ini with (un)quoting support
Requires:       yast2-core >= 2.23.0
Requires:       yast2-hardware-detection
# for SLPAPI.pm
Requires:       yast2-perl-bindings
# changed StartPackage callback signature
Requires:       yast2-pkg-bindings >= 2.20.3
# for y2start
Requires:       yast2-ruby-bindings >= 3.2.10
Requires:       yast2-xml
# new UI::SetApplicationTitle
Requires:       yast2-ycp-ui-bindings >= 3.2.0
Requires:       yui_backend
# scripts for collecting YAST logs
Requires:       yast2-logs
# pre-requires for filling the sysconfig template (sysconfig.yast2)
PreReq:         %fillup_prereq
# xdg-su in .desktops
Recommends:     xdg-utils
# SrvStatusComponent moved to yast2.rpm
Conflicts:      yast2-dns-server < 3.1.17
# InstError
Conflicts:      yast2-installation < 2.18.5
# moved export method
Conflicts:      yast2-installation < 4.1.8
# moved cfg_mail.scr
Conflicts:      yast2-mail < 3.1.7
# Older packager use removed API
Conflicts:      yast2-packager < 4.0.33
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Obsoletes:      yast2-devel-doc
# for the PackageExtractor class, just make sure they are present,
# these should be present even in a very minimal installation
Requires:       cpio
Requires:       rpm

%description
This package contains scripts and data needed for SUSE Linux
installation with YaST2

%prep
%setup -q

%build
%yast_build

# removed explicit adding of translations to group desktop files, since it is covered by the general call (they are in a subdirectory) and it caused build fail

%install
%yast_install

mkdir -p %{buildroot}%{yast_clientdir}
mkdir -p %{buildroot}%{yast_desktopdir}
mkdir -p %{buildroot}%{yast_imagedir}
mkdir -p %{buildroot}%{yast_localedir}
mkdir -p %{buildroot}%{yast_moduledir}
mkdir -p %{buildroot}%{yast_scrconfdir}
mkdir -p %{buildroot}%{yast_ybindir}
mkdir -p %{buildroot}%{yast_ydatadir}
mkdir -p %{buildroot}%{yast_yncludedir}
mkdir -p %{buildroot}%{yast_libdir}
mkdir -p %{buildroot}%{yast_vardir}
mkdir -p %{buildroot}%{yast_vardir}/hooks
mkdir -p %{buildroot}%{yast_schemadir}/control/rnc
mkdir -p %{buildroot}%{yast_schemadir}/autoyast/rnc
mkdir -p %{buildroot}%{_sysconfdir}/YaST2

# symlink the yardoc duplicates, saves over 2MB in installed system
# (the RPM package size is decreased just by few kilobytes
# because of the compression)
%fdupes -s %{buildroot}/%{_docdir}/yast2

%post
%{fillup_only -n yast2}

%files
%defattr(-,root,root)

# basic directory structure

%dir %{yast_clientdir}
%dir %{yast_desktopdir}
%{yast_desktopdir}/groups
%dir %{yast_imagedir}
%dir %{yast_localedir}
%dir %{yast_moduledir}
%dir %{yast_scrconfdir}
%dir %{yast_ybindir}
%dir %{yast_ydatadir}
%dir %{yast_yncludedir}
%dir %{yast_vardir}
%dir %{yast_libdir}
%dir %{yast_schemadir}
%dir %{yast_schemadir}/control
%dir %{yast_schemadir}/control/rnc
%dir %{yast_schemadir}/autoyast
%dir %{yast_schemadir}/autoyast/rnc
%dir %{_sysconfdir}/YaST2
%dir %{yast_vardir}/hooks

# yast2

%{yast_ydatadir}/*.ycp
%{yast_clientdir}/*
%{yast_moduledir}/*
%{yast_libdir}/*
%{yast_scrconfdir}/*
%{yast_ybindir}/*
%{yast_agentdir}/ag_*
%{_fillupdir}/sysconfig.yast2

%{_datadir}/bash-completion/completions/yast2*.sh
# configuration files
%config %{_sysconfdir}/YaST2/XVersion

# documentation (not included in devel subpackage)
%doc %dir %{yast_docdir}
%license %{yast_docdir}/COPYING
%{_mandir}/*/*
%doc %{yast_vardir}/hooks/README.md

/sbin/yast*
%{_sbindir}/yast*

# wizard
%dir %{yast_yncludedir}/wizard
%{yast_yncludedir}/wizard/*.rb

# packages
%dir %{yast_yncludedir}/packages
%{yast_yncludedir}/packages/*.rb

# system
%dir %{yast_yncludedir}/hwinfo
%{yast_yncludedir}/hwinfo/*.rb
%{yast_desktopdir}/messages.desktop

# icons
%{yast_icondir}

%package logs

Summary:        Collecting YAST information
Group:          System/YaST

Provides:       yast2:/usr/sbin/save_y2logs

%description logs
This package contains scripts for handling YAST logs.

%files logs
%defattr(-,root,root)
/usr/sbin/save_y2logs

%changelog

#
# spec file for package yast2
#
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
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
Version:        3.1.175
Release:        0
Url:            https://github.com/yast/yast-yast2

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Source1:        yast2-rpmlintrc

BuildRequires:  perl-XML-Writer
BuildRequires:  update-desktop-files
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-perl-bindings
BuildRequires:  yast2-testsuite
# Needed already in build time
BuildRequires:  yast2-core >= 2.18.12
BuildRequires:  yast2-pkg-bindings >= 2.20.3
BuildRequires:  yast2-ycp-ui-bindings >= 3.1.8

# Needed for tests
BuildRequires:  grep

# for symlinking yardoc duplicates
BuildRequires:  fdupes

# For running RSpec tests during build
BuildRequires:  rubygem(rspec)
# for defining abstract methods in libraries
BuildRequires:  rubygem(abstract_method)
# for running scripts
BuildRequires:  rubygem(cheetah)
# for file access using augeas
BuildRequires:  rubygem(cfa)

# To have Yast::CoreExt::AnsiString
BuildRequires:  yast2-ruby-bindings >= 3.1.36

# pre-requires for filling the sysconfig template (sysconfig.yast2)
PreReq:         %fillup_prereq

# ag_ini section_private
# ag_ini with (un)quoting support
Requires:       yast2-core >= 2.23.0
# for defining abstract methods in libraries
Requires:  rubygem(abstract_method)
# for running scripts
Requires:  rubygem(cheetah)
# for file access using augeas
Requires:  rubygem(cfa)
# new UI::SetApplicationIcon
Requires:       yast2-ycp-ui-bindings >= 3.1.8

# changed StartPackage callback signature
Requires:       yast2-pkg-bindings >= 2.20.3
Requires:       yui_backend
# For Cron Agent, Module
Requires:       perl-Config-Crontab
# for ag_tty (/bin/stty)
# for /usr/bin/md5sum
Requires:       coreutils
Requires:       sysconfig >= 0.80.0
Requires:       yast2-hardware-detection
Requires:       yast2-xml
# for SLPAPI.pm
Requires:       yast2-perl-bindings
# for ag_anyxml
Requires:       perl-XML-Simple
# for GPG.ycp
Requires:       gpg2

# for Punycode.rb (bnc#651893) - the idnconv tool is located in
# different packages (SLE12/Leap-42.1: bind-utils, TW/Factory: idnkit)
%if 0%{?suse_version} >= 1330
Requires:       idnkit
%else
Requires:       bind-utils
%endif

# xdg-su in .desktops
Recommends:     xdg-utils

# moved cfg_security.scr
Conflicts:      yast2-security <= 2.13.2
# moved ag_netd, cfg_netd.scr, cfg_xinetd.scr
Conflicts:      yast2-inetd <= 2.13.4
Conflicts:      yast2-tune < 2.15.6
Obsoletes:      yast2-mail-aliases <= 2.14.0
Conflicts:      yast2-storage < 2.16.4
Conflicts:      yast2-network < 2.16.6
Conflicts:      yast2-sshd < 2.16.1

# moved ag_content agent 
Conflicts:      yast2-instserver <= 2.16.3

# InstError
Conflicts:      yast2-installation < 2.18.5

Conflicts:      yast2-update < 2.16.1
# Older packager use removed API
Conflicts:      yast2-packager < 3.1.34
Conflicts:      yast2-mouse < 2.16.0
Conflicts:      autoyast2-installation < 2.16.2
# country_long.ycp and country.ycp moved to yast2
Conflicts:      yast2-country < 2.16.3
# SrvStatusComponent moved to yast2.rpm
Conflicts:      yast2-dns-server < 3.1.17

Provides:       yast2-lib-sequencer
Obsoletes:      yast2-lib-sequencer
Provides:       yast2-lib-wizard
Provides:       yast2-lib-wizard-devel
Provides:       yast2-trans-wizard
Obsoletes:      yast2-lib-wizard
Obsoletes:      yast2-lib-wizard-devel
Obsoletes:      yast2-trans-wizard
Provides:       y2t_menu
Provides:       yast2-trans-menu
Obsoletes:      y2t_menu
Obsoletes:      yast2-trans-menu

# moved here from another packages
Provides:       yast2-dns-server:/usr/share/YaST2/modules/DnsServerAPI.pm
Provides:       yast2-installation:/usr/share/YaST2/modules/Hotplug.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/HwStatus.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/Installation.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/Product.ycp
Provides:       yast2-mail-aliases
Provides:       yast2-network:/usr/share/YaST2/modules/Internet.ycp
Provides:       yast2-packager:/usr/lib/YaST2/servers_non_y2/ag_anyxml

Requires:       yast2-ruby-bindings >= 3.1.33

Summary:        YaST2 - Main Package
License:        GPL-2.0
Group:          System/YaST

%description
This package contains scripts and data needed for SUSE Linux
installation with YaST2

%package devel-doc
Requires:       yast2 = %version
Provides:       yast2-lib-sequencer-devel
Obsoletes:      yast2-devel
Obsoletes:      yast2-lib-sequencer-devel
Provides:       yast2-devel
Requires:       yast2-core-devel

Summary:        YaST2 - Development Scripts and Documentation
Group:          System/YaST

%description devel-doc
This package contains scripts and data needed for a SUSE Linux
installation with YaST2.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

# removed explicit adding of translations to group desktop files, since it is covered by the general call (they are in a subdirectory) and it caused build fail

%install
%yast_install

mkdir -p "$RPM_BUILD_ROOT"%{yast_clientdir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_desktopdir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_imagedir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_localedir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_moduledir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_scrconfdir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_ybindir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_ydatadir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_yncludedir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_libdir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_vardir}
mkdir -p "$RPM_BUILD_ROOT"%{yast_vardir}/hooks
mkdir -p "$RPM_BUILD_ROOT"%{yast_schemadir}/control/rnc
mkdir -p "$RPM_BUILD_ROOT"%{yast_schemadir}/autoyast/rnc
mkdir -p "$RPM_BUILD_ROOT"/etc/YaST2

# symlink the yardoc duplicates, saves over 2MB in installed system
# (the RPM package size is decreased just by few kilobytes
# because of the compression)
%fdupes -s %buildroot/%_prefix/share/doc/packages/yast2

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
/var/adm/fillup-templates/sysconfig.yast2

# configuration files
%config %{_sysconfdir}/bash_completion.d/yast2*.sh
%config %{_sysconfdir}/YaST2/XVersion

# documentation (not included in devel subpackage)
%doc %dir %{yast_docdir}
%doc %{yast_docdir}/COPYING
%doc %{_mandir}/*/*
%doc %{yast_vardir}/hooks/README.md

/sbin/*
%{_sbindir}/*

# wizard
%dir %{yast_yncludedir}/wizard
%{yast_yncludedir}/wizard/*.rb

#packags
%dir %{yast_yncludedir}/packages
%{yast_yncludedir}/packages/*.rb

#system
%dir %{yast_yncludedir}/hwinfo
%{yast_yncludedir}/hwinfo/*.rb
%{yast_desktopdir}/messages.desktop

# documentation

%files devel-doc
%defattr(-,root,root)

%doc %{yast_docdir}/autodocs
%doc %{yast_docdir}/commandline
%doc %{yast_docdir}/control
%doc %{yast_docdir}/cron
%doc %{yast_docdir}/cwm
%doc %{yast_docdir}/desktop
%doc %{yast_docdir}/gpg
%doc %{yast_docdir}/log
%doc %{yast_docdir}/network
%doc %{yast_docdir}/packages
%doc %{yast_docdir}/runlevel
%doc %{yast_docdir}/sequencer
%doc %{yast_docdir}/system
%doc %{yast_docdir}/types
%doc %{yast_docdir}/wizard
%doc %{yast_docdir}/xml
%doc %{yast_docdir}/general

%changelog

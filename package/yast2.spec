#
# spec file for package yast2
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        3.1.3
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
Source1:        yast2-rpmlintrc

BuildRequires:  perl-XML-Writer update-desktop-files yast2-perl-bindings yast2-testsuite
BuildRequires:  yast2-devtools >= 3.0.6
# Needed already in build time
BuildRequires:  yast2-core >= 2.18.12 yast2-pkg-bindings >= 2.20.3 yast2-ycp-ui-bindings >= 2.18.4

# Needed for tests
BuildRequires:  rubygem-rspec

# for symlinking yardoc duplicates
BuildRequires:  fdupes

# For running RSpec tests during build
BuildRequires:  rubygem-rspec

# pre-requires for filling the sysconfig template (sysconfig.yast2)
PreReq:         %fillup_prereq

# ag_ini section_private
# ag_ini with (un)quoting support
Requires:       yast2-core >= 2.23.0
# Mod_UI
# new UI::OpenContextMenu
Requires:       yast2-ycp-ui-bindings >= 2.18.4

# changed StartPackage callback signature
Requires:       yast2-pkg-bindings >= 2.20.3
Requires:       yui_backend 
# For Cron Agent, Module
Requires:       perl-Config-Crontab
# for ag_tty (/bin/stty)
# for /usr/bin/md5sum
Requires:       coreutils sysconfig >= 0.80.0
Requires:       yast2-xml yast2-hardware-detection
# for SLPAPI.pm
Requires:       yast2-perl-bindings
# for ag_anyxml
Requires:       perl-XML-Simple
# RegistrationStatus.pm
Requires:       perl-XML-XPath
# for GPG.ycp
Requires:       gpg2
# for Punycode.ycp (bnc#651893)
Requires:       bind-utils
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

# moved RegistrationStatus.pm here from wagon (fate#312712)
Conflicts:      yast2-wagon <= 2.22.2

# InstError
Conflicts:      yast2-installation < 2.18.5

Conflicts:      yast2-update < 2.16.1
# Modules 'Slides' and 'SlideShow' moved from yast2-packager to yast2
Conflicts:      yast2-packager < 2.17.12
Conflicts:      yast2-mouse < 2.16.0
Conflicts:      autoyast2-installation < 2.16.2
# country_long.ycp and country.ycp moved to yast2
Conflicts:      yast2-country < 2.16.3
# DnsServerAPI moved to yast2.rpm (by mzugec)
Conflicts:      yast2-dns-server < 2.17.0

Provides:       yast2-lib-sequencer
Obsoletes:      yast2-lib-sequencer
Provides:       yast2-lib-wizard yast2-lib-wizard-devel yast2-trans-wizard
Obsoletes:      yast2-lib-wizard yast2-lib-wizard-devel yast2-trans-wizard
Provides:       yast2-trans-menu y2t_menu
Obsoletes:      yast2-trans-menu y2t_menu

# moved here from another packages
Provides:       yast2-installation:/usr/share/YaST2/modules/Installation.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/Product.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/Hotplug.ycp
Provides:       yast2-installation:/usr/share/YaST2/modules/HwStatus.ycp
Provides:       yast2-network:/usr/share/YaST2/modules/Internet.ycp
Provides:       yast2-packager:/usr/lib/YaST2/servers_non_y2/ag_anyxml
Provides:       yast2-dns-server:/usr/share/YaST2/modules/DnsServerAPI.pm
Provides:       yast2-mail-aliases

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:        YaST2 - Main Package

%description
This package contains scripts and data needed for SuSE Linux
installation with YaST2

%package devel-doc
Requires:       yast2 = %version
Group:          System/YaST
Provides:       yast2-lib-sequencer-devel
Obsoletes:      yast2-lib-sequencer-devel
Obsoletes:      yast2-devel
Provides:       yast2-devel
Requires:       yast2-core-devel

Summary:        YaST2 - Development Scripts and Documentation

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
mkdir -p "$RPM_BUILD_ROOT"%{yast_vardir}
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
%dir %{yast_schemadir}
%dir %{yast_schemadir}/control
%dir %{yast_schemadir}/control/rnc
%dir %{yast_schemadir}/autoyast
%dir %{yast_schemadir}/autoyast/rnc
%dir %{_sysconfdir}/YaST2

# yast2

%{yast_ydatadir}/*.ycp
%{yast_clientdir}/*
%{yast_moduledir}/*
%{yast_scrconfdir}/*
%{yast_ybindir}/*
%{yast_agentdir}/ag_*
%{_sysconfdir}/bash_completion.d/yast2*.sh
%{_sysconfdir}/YaST2/XVersion
/var/adm/fillup-templates/sysconfig.yast2

# documentation (not included in devel subpackage)
%doc %dir %{yast_docdir}
%doc %{yast_docdir}/COPYING
%doc %{_mandir}/*/*

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

%changelog

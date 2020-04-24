#
# spec file for package yast2
#
# Copyright (c) 2019 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           yast2
Version:        4.2.82
Release:        0
Summary:        YaST2 Main Package
License:        GPL-2.0-only
Group:          System/YaST
Url:            https://github.com/yast/yast-yast2

Source0:        %{name}-%{version}.tar.bz2
Source1:        yast2-rpmlintrc

# for symlinking yardoc duplicates
BuildRequires:  fdupes
# Needed for tests
BuildRequires:  grep
# for some system directories
BuildRequires:  filesystem
BuildRequires:  perl-XML-Writer
# for defining abstract methods in libraries
BuildRequires:  rubygem(%{rb_default_ruby_abi}:abstract_method)
# for file access using augeas
BuildRequires:  rubygem(%{rb_default_ruby_abi}:cfa)
# for used augeas lenses
BuildRequires:  augeas-lenses
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
# Pkg.Resolvables()
BuildRequires:  yast2-pkg-bindings >= 4.2.0
BuildRequires:  rubygem(%rb_default_ruby_abi:yast-rake)
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
# for used augeas lenses
Requires:       augeas-lenses
# For converting to/from punycode strings
Requires:       sysconfig >= 0.80.0
Requires:       rubygem(%{rb_default_ruby_abi}:simpleidn)
# for running scripts
Requires:       rubygem(%{rb_default_ruby_abi}:cheetah)
# ag_ini section_private
# ag_ini with (un)quoting support
Requires:       yast2-core >= 2.23.0
Requires:       yast2-hardware-detection
# for SLPAPI.pm
Requires:       yast2-perl-bindings
# Pkg.Resolvables()
Requires:       yast2-pkg-bindings >= 4.2.0
# for y2start
Requires:       yast2-ruby-bindings >= 3.2.10
Requires:       yast2-xml
# new UI::SetApplicationTitle
Requires:       yast2-ycp-ui-bindings >= 3.2.0
Requires:       yui_backend
# scripts for collecting YAST logs
Requires:       yast2-logs
# for the PackageExtractor class, just make sure they are present,
# these should be present even in a very minimal installation
Requires:       cpio
Requires:       rpm
# /usr/bin/hostname command
Requires:       hostname
# pre-requires for filling the sysconfig template (sysconfig.yast2)
PreReq:         %fillup_prereq

# xdg-su in .desktops
Recommends:     xdg-utils

# removed the XVersion API
Conflicts:      yast2-country < 4.2.3
# SrvStatusComponent moved to yast2.rpm
Conflicts:      yast2-dns-server < 3.1.17
# removed the XVersion API
Conflicts:      yast2-installation < 4.2.9
# moved cfg_mail.scr
Conflicts:      yast2-mail < 3.1.7
# y2packager/repository.rb has been moved here
Conflicts:      yast2-packager < 4.2.46
# Older snapper does not provide machine-readable output
Conflicts:	snapper < 0.8.6

Obsoletes:      yast2-devel-doc

%description
This package contains scripts and data needed for SUSE Linux
installation with YaST2

%package logs
Summary:        Scripts for handling YAST logs
Group:          System/YaST

Provides:       yast2:/usr/sbin/save_y2logs

Requires:       tar

%description logs
This package contains scripts for handling YAST logs.

%prep
%setup -q

%check
export Y2STRICTTEXTDOMAIN=1
%yast_check

%build

# removed explicit adding of translations to group desktop files, since it is covered by the general call (they are in a subdirectory) and it caused build fail

%install
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

%yast_install

# symlink the yardoc duplicates, saves over 2MB in installed system
# (the RPM package size is decreased just by few kilobytes
# because of the compression)
%fdupes -s %{buildroot}/%{_docdir}/yast2

%post
%{fillup_only -n yast2}

if [ -f "/etc/sysctl.d/30-yast.conf" ]; then
    if [ -f "/etc/sysctl.d/70-yast.conf" ]; then
        rm /etc/sysctl.d/30-yast.conf
    else
        mv /etc/sysctl.d/30-yast.conf /etc/sysctl.d/70-yast.conf
    fi
fi

%files

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

%{_datadir}/bash-completion/completions

# documentation (not included in devel subpackage)
%doc %dir %{yast_docdir}
%license %{yast_docdir}/COPYING
%doc %{yast_docdir}/README.md

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

%files logs
/usr/sbin/save_y2logs

%changelog

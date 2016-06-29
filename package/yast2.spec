#
# spec file for package yast2
#
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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
Version:        3.1.192
Release:        0
Summary:        YaST2 - Main Package
License:        GPL-2.0
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
BuildRequires:  rubygem(%{rb_default_ruby_abi}:cheetah)
# For running RSpec tests during build
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  update-desktop-files
# Needed already in build time
BuildRequires:  yast2-core >= 2.18.12
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-perl-bindings
BuildRequires:  yast2-pkg-bindings >= 2.20.3
# To have Yast::CoreExt::AnsiString
BuildRequires:  yast2-ruby-bindings >= 3.1.36
BuildRequires:  yast2-testsuite
BuildRequires:  yast2-ycp-ui-bindings >= 3.1.8
# FIXME make it optional
BuildRequires:  rubygem(%{rb_default_ruby_abi}:ruby-lint)

# for ag_tty (/bin/stty)
# for /usr/bin/md5sum
Requires:       coreutils
# for GPG.ycp
Requires:       gpg2
# For Cron Agent, Module
Requires:       perl-Config-Crontab
# for ag_anyxml
Requires:       perl-XML-Simple
# for defining abstract methods in libraries
Requires:       rubygem(%{rb_default_ruby_abi}:abstract_method)
# for file access using augeas
Requires:       rubygem(%{rb_default_ruby_abi}:cfa)
# for running scripts
Requires:       rubygem(%{rb_default_ruby_abi}:cheetah)
Requires:       sysconfig >= 0.80.0
# ag_ini section_private
# ag_ini with (un)quoting support
Requires:       yast2-core >= 2.23.0
Requires:       yast2-hardware-detection
# for SLPAPI.pm
Requires:       yast2-perl-bindings
# changed StartPackage callback signature
Requires:       yast2-pkg-bindings >= 2.20.3
Requires:       yast2-ruby-bindings >= 3.1.33
Requires:       yast2-xml
# new UI::SetApplicationIcon
Requires:       yast2-ycp-ui-bindings >= 3.1.8
Requires:       yui_backend
# pre-requires for filling the sysconfig template (sysconfig.yast2)
PreReq:         %fillup_prereq
# xdg-su in .desktops
Recommends:     xdg-utils
# SrvStatusComponent moved to yast2.rpm
Conflicts:      yast2-dns-server < 3.1.17
# InstError
Conflicts:      yast2-installation < 2.18.5
# moved cfg_mail.scr
Conflicts:      yast2-mail < 3.1.7
# Older packager use removed API
Conflicts:      yast2-packager < 3.1.34
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
# for Punycode.rb (bnc#651893) - the idnconv tool is located in
# different packages (SLE12/Leap-42.1: bind-utils, TW/Factory: idnkit)
%if 0%{?suse_version} >= 1330
Requires:       idnkit
%else
Requires:       bind-utils
%endif

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

# to be made a separate script, with --constant and --directory
# $1 --constant
# $2
# $3 --directory to place the result in
# $4
# $5 --ruby-eval
# $6
ruby_lint_definition_generator() {
  export RLCONST="$2"
  export RLDIR="$4"
  export RLEVAL="$6"

  mkdir -p "$RLDIR"
  ruby -r ruby-lint -r ruby-lint/definition_generator \
    -e "$RLEVAL" \
    -e 'RubyLint::DefinitionGenerator.new(ENV["RLCONST"],ENV["RLDIR"]).generate'

  # fixup https://github.com/YorickPeterse/ruby-lint/issues/190
  sed -i -e '/define_(/d' "$RLDIR"/*.rb
}

# rpm macro for ruby to shorten this?
export RLBASEDIR=$RPM_BUILD_ROOT/%{_libdir}/ruby/vendor_ruby/%{rb_ver}/ruby-lint/definitions/rpms
MYRLDIR=$RLBASEDIR/%{name}

# definitions for UI
ruby_lint_definition_generator \
    --constant Yast::UI \
    --directory $RLBASEDIR/yast2-ycp-ui-bindings \
    --ruby-eval "require 'yast'; Yast.import('UI')"

# simpler name?
export Y2DIR=%{buildroot}/%{yast_moduledir}/..

# definitions for this package... oh sh**
MS=$(ruby -e '
Dir.chdir(ENV["Y2DIR"]+"/modules") do
  puts Dir.glob("[A-Z]*.rb").map {|fn| fn.sub(/.rb$/,"")}.sort
end
')
for M in $MS; do
    # "for MM im $M ${M}Class" fails with
    # inspector.rb:41:in `inspect_constants': undefined method `name' for #<Yast::ALogClass:0x00000001c09f80> (NoMethodError)
    for MM in ${M}Class; do
        ruby_lint_definition_generator \
            --constant Yast::$MM \
            --directory $MYRLDIR/$MM \
            --ruby-eval "require 'yast'; Yast.import('$M')"
    done
done

# now lint yourself with the help of the definitions just created
ruby -e '
File.open("ruby-lint.yml", "w") do |f|
  f.puts "presenter: emacs"
  f.puts "requires:"
  Dir.glob(ENV["RLBASEDIR"] + "/**/*.rb").each do |r|
    f.puts "  - #{r}"
  end
end
'
# the pipe also masks exit codes
ruby-lint library/*/src | tee $MYRLDIR/report.log
: "Total ruby-lint reports:"
wc -l $MYRLDIR/report.log

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
%{_localstatedir}/adm/fillup-templates/sysconfig.yast2

# configuration files
%config %{_sysconfdir}/bash_completion.d/yast2*.sh
%config %{_sysconfdir}/YaST2/XVersion

# documentation (not included in devel subpackage)
%doc %dir %{yast_docdir}
%doc %{yast_docdir}/COPYING
%{_mandir}/*/*
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

%{_libdir}/ruby/vendor_ruby/%{rb_ver}/ruby-lint/definitions/rpms/yast2-ycp-ui-bindings
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/ruby-lint/definitions/rpms/%{name}

%changelog

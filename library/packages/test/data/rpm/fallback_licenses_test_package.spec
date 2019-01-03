# Spec file for package licenses-test-package
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# This is just a testing dummy package for verifying the package
# extraction functionality, it only contains a single testing text file.
#
# Run "rpmbuild -bb fallback_licenses_test_package.spec" to build the package.

Name:           fallback_licenses_test_package

Version:        0.1
Release:        0
Summary:        A package to test licenses fetchers and handlers
License:        MIT
Group:          Metapackages
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

%define LicensesDir %{_prefix}/etc/YaST2/licenses/%{name} 
%define ReadmeDir %{_prefix}/share/doc/packages/%{name} 

%description
This is just a package for testing licenses fetchers and handlers, based on a sled-release package.
In this case, there is only the "fallback" license file: LICENSE.TXT, which does not include the
language code as part of its name.

%prep

%install
# install a dummy test file
mkdir -p $RPM_BUILD_ROOT/%{ReadmeDir}
mkdir -p $RPM_BUILD_ROOT/%{LicensesDir}

echo "Just a package to test licenses" > $RPM_BUILD_ROOT/%{ReadmeDir}/README
echo "Dummy content for the fallback license file" > $RPM_BUILD_ROOT/%{LicensesDir}/LICENSE.TXT

%files
%defattr(644,root,root,755)
%dir %{LicensesDir}
%{LicensesDir}/*
%doc %dir %{ReadmeDir}
%doc %{ReadmeDir}/README

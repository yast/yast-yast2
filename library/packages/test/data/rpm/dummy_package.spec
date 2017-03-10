#
# spec file for package dummy_package
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
# Run "rpmbuild -bb dummy_package.spec" to build the package.

Name:           dummy_package

Version:        0.1
Release:        0
Summary:        A dummy package
License:        MIT
Group:          Metapackages
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

%description
This is just a dummy package for testing.

%prep

%install
# install a dummy test file
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/%{name}
echo "just a testing dummy package" > $RPM_BUILD_ROOT/%{_prefix}/share/doc/packages/%{name}/test

%files
%defattr(644,root,root,755)
%doc %dir %{_prefix}/share/doc/packages/%{name}
%doc %{_prefix}/share/doc/packages/%{name}/


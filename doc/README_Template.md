
YaST &lt;FOO&gt; Module
=======================

<!-- Adapt the used badges, keep the order unchanged so it is unified for all repositories -->
[![Travis Build](https://travis-ci.org/yast/yast-foo.svg?branch=master)](https://travis-ci.org/yast/yast-foobar)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-foo-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-foo-master/)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-foobar.svg)](https://coveralls.io/r/yast/yast-foobar?branch=master)
[![Code Climate](https://codeclimate.com/github/yast/yast-foobar/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-foobar)
[![Inline docs](http://inch-ci.org/github/yast/yast-foobar.svg?branch=master)](http://inch-ci.org/github/yast/yast-foobar)

> *This file is a `README.md` template for YaST modules.*

>  *Keep the file reasonably short, if some section becomes too long put the details in
>  a separate file and link the content from here. Remove the unneeded sections.*


Description
============

> *This should be a short description for users of the module.*

This YaST module configures ....

### Features ###

- ...
- ...

### Limitations ###

- ...
- ...


Development
===========

This module is developed as part of YaST. See the generic
[development documentation](README_Generic.md#yast-development-documentation) and
[development environment](README_Generic.md#development-environment) description.


Getting the Sources
===================

To get the source code, clone the GitHub repository:

    $ git clone https://github.com/yast/<repository>.git

Alternatively, you can fork the repository and clone your fork. This is most
useful if you plan to contribute into the project and you do not have push
permission to the repository.

Development Environment
=======================

> *If the module needs specific development setup then describe it here,
> otherwise remove this section.*


Installing and Starting the Module
===================================

<!-- select the appropriate link depending whether rake or make is used -->
See [the generic building, installing](README_Generic_Rake.md#building-and-installaing)
and [running](README_Generic_Rake.md#starting-the-module) documentation.

See [the generic building, installing](README_Generic_Autotools.md#building-and-installaing)
and [running](README_Generic_Autotools.md#starting-the-module) documentation.


Testing Environment
===================

> *Here describe (or link the docu, man pages,...) how to setup a specific environment
> needed for running and testing the module.*

> *Example: for iSCSI client you might describe (or link) how to setup an iSCSI server
> so it could be used by the client module.*


Tests and Continuous Integration
================================

The tests are also run at a CI server, see
the [generic CI documentation](README_Generic.md#continuous-integration)


Building and Submitting the Package
===================================

Before submitting any change please read our [contribution
guidelines](CONTRIBUTING.md).

<!-- select the appropriate link depending whether rake or make is used -->
See the generic YaST documentation how to
[build](README_Generic_Autotools.md#building-the-package)
[build](README_Generic_Rake.md#building-the-package)
a package and [submit](README_Generic.md#submitting-the-package) it to the Open Build Service (OBS).


Troubleshooting
===============

> *Here you can describe (or link) some usefull hints for common problems when <b>developing</b> the module.
> You should describe just tricky solutions which need some deep knowledge about the module or
> the system and it is difficult to figure it out.*

> *Example: If the module crashes after compiling and installing a new version remove `/var/cache/foo/`
> content and start it again.*


Contact
=======

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the
[#yast](https://webchat.freenode.net/?channels=%23yast) IRC channel on freenode.

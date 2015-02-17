YaST - The Basic Libraries
==========================

[![Travis Build](https://travis-ci.org/yast/yast-yast2.svg?branch=master)](https://travis-ci.org/yast/yast-yast2)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-yast2.svg)](https://coveralls.io/r/yast/yast-yast2?branch=master)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-yast2-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-yast2-master/)
[![Code Climate](https://codeclimate.com/github/yast/yast-yast2/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-yast2)

This repository contains basic set of shared libraries and so-called SCR agents
used for reading and writing configuration files and some even for executing
commands on the system.


Provided Functionality
======================

See [the generated yardoc documentation](http://www.rubydoc.info/github/yast/yast-yast2) at rubydoc.info.

Development
===========

This module is developed as part of YaST. See the generic
[development documentation](doc/README_Generic.md#yast-development-documentation) and
[development environment](doc/README_Generic.md#development-environment) description.


Getting the Sources
===================

To get the source code, clone the GitHub repository:

    $ git clone https://github.com/yast/yast-yast2.git

Alternatively, you can fork the repository and clone your fork. This is most
useful if you plan to contribute into the project and you do not have push
permission to the repository.


Installing the Library
======================

See [the generic building and installing](doc/README_Generic_Autotools.md#building-and-installaing)
documentation.


Tests and Continuous Integration
================================

The tests are also run at a CI server, see
the [generic CI documentation](doc/README_Generic.md#continuous-integration)


Building and Submitting the Package
===================================

Before submitting any change please read our [contribution
guidelines](CONTRIBUTING.md).

See the generic YaST documentation how to 
[build](doc/README_Generic_Autotools.md#building-the-package)
 a package and [submit](doc/README_Generic.md#submitting-the-package) it to the Open Build Service (OBS).


Contact
=======

If you have any question, feel free to ask at the [development mailing
list](http://lists.opensuse.org/yast-devel/) or at the
[#yast](https://webchat.freenode.net/?channels=%23yast) IRC channel on freenode.


YaST &lt;FOO&gt; Module
=======================

<!-- Adapt the used badges, keep the order unchanged so it is unified for all repositories.
  To use the badges replace "foo" by the real repository name.  -->
[![Travis Build](https://travis-ci.org/yast/yast-foo.svg?branch=master)](https://travis-ci.org/yast/yast-foobar)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-foo-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-foo-master/)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-foobar.svg)](https://coveralls.io/r/yast/yast-foobar?branch=master)
[![Code Climate](https://codeclimate.com/github/yast/yast-foobar/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-foobar)
[![Inline docs](http://inch-ci.org/github/yast/yast-foobar.svg?branch=master)](http://inch-ci.org/github/yast/yast-foobar)

> *This file is a `README.md` template for YaST modules.*

>  *Keep the file reasonably short, if some section becomes too long put the details in
>  a separate file and link the content from here. Remove the unneeded sections.*

> **This file should describe the module for developers, like:**
> * What is the project good for - what does it actually do (and how),
>   what it cannot do (unsupported scenarios), limitations
> * Links to the documentation, high level and low level descriptions
>   (e.g. RFC, wikipedia articles, man pages, project documentation,
>   openSUSE wiki), terminology
> * How to fetch the source code (if something outside Git is needed it
>   should be mentioned)
> * What prerequisites are needed to build the sources (external
>   libraries, gems, scripts, …)
> * How to build the sources (make/rake commands…)
> * How to setup a testing environment (e.g. iSCSI target for iSCSI client)
> * How to run the code to test a change (esp. needed for non trivial
>   projects like linuxrc)
> * How to run automated tests
> * How to build a package for submission
> * How to submit the package (if it needs some manual steps)
> * Troubleshooting (how to solve typical problems) 


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

This module is developed as part of YaST. See the
[development documentation](http://yastgithubio.readthedocs.org/en/latest/development/).


Getting the Sources
===================

To get the source code, clone the GitHub repository:

    $ git clone https://github.com/yast/<repository>.git

If you want to contribute into the project you can
[fork](https://help.github.com/articles/fork-a-repo/) the repository and clone your fork.


Development Environment
=======================

> *If the module needs specific development setup then describe it here,
> otherwise remove this section.*


Testing Environment
===================

> *Here describe (or link the docu, man pages,...) how to setup a specific environment
> needed for running and testing the module.*

> *Example: for iSCSI client you might describe (or link) how to setup an iSCSI server
> so it could be used by the client module.*


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

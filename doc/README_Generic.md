Generic YaST README File
========================

YaST Development Documentation
------------------------------

- [YaST development documentation](http://yast.github.io/documentation.html)
- [Contribution Guidelines](http://yast.github.io/guidelines.html)
- [YaST architecture](http://yastgithubio.readthedocs.org/en/latest/architecture)
- [Development environment](https://en.opensuse.org/openSUSE:YaST:_Preparing_the_Development_Environment)


Development Environment
-----------------------
Before doing anything useful with the code, you need to setup a development
environment. Fortunately, this is quite simple, see the [preparing development
environment](https://en.opensuse.org/openSUSE:YaST:_Preparing_the_Development_Environment)
documentation.


### Extra Development Tools ###

For running the automated tests you might need to install some more packages:

    $ sudo zypper install yast2-testsuite rubygem-rspec rubygem-simplecov


Continuous Integration
======================

Travis CI
---------

YaST uses [Travis CI](https://travis-ci.org) for building and running tests for commits and pull requests.
You can find more details in the [Travis CI Integration]
(http://yastgithubio.readthedocs.org/en/latest/travis-integration/) documentation.

Jenkins CI
----------

For builing on native (open)SUSE distibution we use
[Jenkins CI openSUSE server](https://ci.opensuse.org/view/Yast/). It also [submits](#automatic-submission) the
built package to OBS.


Submitting the Package
======================

Automatic Submission
--------------------

The changes in `master` branch are automatically built and submitted to
[YaST:HEAD](https://build.opensuse.org/project/show/YaST:Head) OBS project
by [Jenkins CI](https://ci.opensuse.org/view/Yast/) after successful build. If the package version is changed then
a submit request to [openSUSE:Factory](https://build.opensuse.org/project/show/openSUSE:Factory)
is created automatically.

Manual Submission
-----------------

First build the package as described above. Then copy the content of `package/` directory to OBS project.

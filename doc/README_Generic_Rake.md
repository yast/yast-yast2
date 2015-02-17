Rake Based YaST Packages
========================

This is a generic documenation for YaST packages which use `rake` for building the package.

Building and Installaing
------------------------

So far the rake based modules do not need to be built, they are ready to be used just
after the Git clone.

To install module run:

    $ sudo rake install

Note: This will overwrite the existing module in the system, be carefull when installing
a shared component (library) as it migth break some other modules.

Starting the Module
-------------------

You can [start the installed module](README_Generic_Autotools.md#starting-the-module)
or you can run it directly from the Git checkout without need to install it first

To run the module directly from the source code, use the `run` Rake task:

    $ rake run


Running the Automated Tests
---------------------------

To run the testsuite, use the `test:unit` Rake task:

    $ rake test:unit

To run the tests with code coverage reporting run

    $ COVERAGE=1 rake test:unit


For a complete list of tasks, run `rake -T`.


Building the Package
--------------------

To build a package for submitting into [Open Build Service](https://build.opensuse.org/) (OBS) you need to run

    $ rake tarball


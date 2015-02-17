Autotools Based YaST Packages
=============================

This is a generic documenation for YaST packages which use autotools (autoconf/automake)
for building the package.

Building and Installaing
--------------------------

To build the module run these commands:

    $ make -f Makefile.cvs
    $ make

If you want to rebuild the module later simply run `make` again.

To install it run:

    $ sudo make install

Note: This will overwrite the existing module in the system, be carefull when installing
a shared component (library) as it migth break some other modules.


Starting the Module
-------------------

Run the module as root

    # yast2 <module>

or start the YaST control panel from the desktop menu and then run the appropriate module.


Running the Automated Tests
---------------------------

To run the testsuite, use the `check` target:

    $ make check


Building the Package
--------------------

To build a package for submitting into [Open Build Service](https://build.opensuse.org/) (OBS) you need to run

    $ make package-local

in the top level directory.

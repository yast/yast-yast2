# YaST - The Basic Libraries #

[![Travis Build](https://travis-ci.org/yast/yast-yast2.svg?branch=master)](https://travis-ci.org/yast/yast-yast2)
[![Jenkins Build](http://img.shields.io/jenkins/s/https/ci.opensuse.org/yast-yast2-master.svg)](https://ci.opensuse.org/view/Yast/job/yast-yast2-master/)
[![Code Climate](https://codeclimate.com/github/yast/yast-yast2/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-yast2)

This repository contains basic set of shared libraries and so-called SCR agents
used for reading and writing configuration files and some even for executing
commands on the system.

## Installation ##

    make -f Makefile.cvs
    make
    sudo make install

## Running Testsuites ##

    make check

## Links ##

  * See more at http://en.opensuse.org/openSUSE:YaST_development

# Adding Support for the `/etc` + `/usr/etc` Layout

## About

This document tries to summarize our findings about the proposal to split the configuration files
into `/usr/etc` (vendor) and `/etc` (user) directories. As you may know, YaST reads and writes
information to many files under `/etc`, so we need to find a way to cope with this (future) layout.

## How to Read the Configuration

In the future, it is expected that vendor configuration files live under `/usr/etc` and user
configuration is placed in `/etc`. Given a `example` application, the rules to determine the
configuration are:

* If `/etc/example.conf` does not exist, read `/usr/etc/example.conf`, `/usr/etc/example.d/*.conf`
  and, finally, `/etc/example.d/*.conf`. The latter has precedence.
* If `/etc/example.conf` does exist, just ignore the configuration under `/usr/etc` and consider
  `/etc/example.conf` and `/etc/example.d/*.conf` only.

YaST will merge settings from those files.

## Impact in YaST

When it comes to reading or writing configuration files, YaST uses mainly two different mechanisms:

* The new [config_files_api](https://github.com/config-files-api/config_files_api) (a.k.a. CFA) API.
* The [good old agents](https://github.com/yast/yast-core/), which are spread through all YaST
  codebase (search for `.scr`) files.

It means that we need to adapt CFA classes and agents to the new scenario. The next section proposes
a simple solution which we have just implemented to handle modifications to `sysctl` settings and,
the last one, proposes a complex but more general solution.

## A Simple Solution for `sysctl.conf`

In a nutshell, jsc#SLE-9077 states that `/etc/sysctl.conf` should not be modified.  So if you want
to modify any `sysctl` setting, you should drop a file in `/etc/sysctl.d` containing the new values.

As a first step, we have added a {Yast2::CFA::Sysctl} class which offers an API to sysctl settings.
This new class uses `/etc/sysctl.d/30-yast.conf` instead of `/etc/sysctl.conf` to write the configuration.
Moreover, it updates known keys that are present in the original `/etc/sysctl.conf` to avoid confusion.

## An Elaborated Proposal

### Extending CFA

CFA offers an object-oriented way to read and write configuration files and, nowadays, it is used
for `zypp.conf`, `chrony.conf`, `ifroute-*` and `ifcfg-*` files, etc. CFA is built around these abstractions:

* **File handlers* provide access to files. By default, it simply uses the `File` class, but it can
  be replaced with other mechanisms to allow, e.g., accessing over the network. Actually, YaST uses
  a specific class,
  [TargetFile](https://github.com/yast/yast-yast2/blob/4efda93ac2221591965450570aa9a9dfad790132/library/system/src/lib/yast2/target_file.rb#L51),
  which respects {Yast::Installation.destdir}. See the discussion about supporting agents to find
  another use case.
* *Parsers* analyze and extract configuration from files. Usually, CFA parsers use Augeas under the
  hood.
* *Models* offer an object-oriented API to a access a configuration file.

Usually, a model is meant to represent a configuration file, but in a layout where the configuration
is spread through several files, this approach could be pretty inconvenient. So, in order to support
the new layout, we are introducing a new layer that abstracts the details of merging and building
the model instance.

The new `loader` classes offer an API to `#load` and `#save` the configuration files. On the one
hand, the default loader (`Loader` class) would read the information from a single file. On the
other hand, an alternative loader (`VendorLoader`) would build the configuration model by reading
vendor and user settings.

When it comes to writing the changes, the `VendorLoader` class will write changes to the `.d`
directory if it exists.

At this point in time, you can check a proof-of-concept in
[config-files-api/config_files_api#32](https://github.com/config-files-api/config_files_api/pull/32).

### Adapting the Agents

Agents are used through all YaST code to read/write configuration settings. In order to support the
new layout, we could follow (at least) these approaches:

* Extend [agents](https://github.com/yast/yast-core/) to support reading/writing from/to different
  files. At least `any`, `ini` and `modules` would need to be adapted.
* Extend CFA to support reading/writing information from agents. It can be done by creating a
  specific *file handler* for agents. See [yast/yast-yast2 usr-etc-support
  branch](https://github.com/yast/yast-yast2/compare/usr-etc-support?expand=1) for a
  proof-of-concept.

At first sight, extending the agents should minimize the changes through YaST codebase. However,
although extending CFA would require more work, it would force us to adapt a CFA based approach to
handle the configuration.

Finally, the `non-y2` agent handles a few scripts that we should consider in a case by case basis
(search for `servers_non_y2`).

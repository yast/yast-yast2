# Hooks

Hooks is the recommended way of executing custom scripts in the context of
some pre-defined workflow, e.g. installation or update process.


## What is a hook

Hook is an action which will be triggered at some predefined [checkpoint](#checkpoints)
during a running workflow. The action includes: 

* searching for files matching [pre-defined patterns](#file-name-format) in a specific 
  directory 
* executing those files sequentially.

The results of the scripts do not affect the workflow, failed script are registered
and logged as well as the succeeded ones. The author of the hook scripts should
however keep in mind that he should not make any changes to the underlying system
that could negatively impact the parent workflow.


## What is not a hook

Hook is not a system extension (an add-on), but a workflow extension. A hook may be
a part of an add-on product, but should not contain logic and code intended for
the add-on.


## Requirements

A hook file must meet following requirements:

* it must be an executable file with all its dependencies satisfied
* it must follow the hook [file naming convention](#file-name-format)
* it must be an [idempotent script](#script-idempotence) that can be executed multiple times
* it must not be interactive
* it must be located in the [hook search path](#search-path)
* the code within the script must not access the X session


### File name format

The hook script file name consists of 3 parts.

The first part of the file name is derived from the events significant for the 
running workflow, e.g. `installation_start`, `after_setup_dhcp`

The second part of the file name contains two integers setting up the sequence in
which the scripts will be executed in case you have multiple scripts for a single hook.

The third part of the file name may be arbitrarily chosen to fit the needs of 
the user or admin.

#### Example

* `installation_start_00_do_some_things.rb`
* `after_setup_dhcp_00_ping_remote_server.sh`


### Script idempotence

The author of a script code must expect the hook to be executed multiple times
during the workflow for various reasons, e.g. the UI may allow the user to go back
and forth in a wizard, or abort the process and start again. 


### Search path

Search path is the the workflow specific directory where the hook scripts are expected
to be stored during its runtime. In general the default search path is 
`var/lib/YaST2/hooks`, but this might be altered by the underlying workflow, e.g. 
installation will search for hook scripts in path `/var/lib/YaST2/hooks/installation`.


## Environment

The hooks are executed with **root** privileges so it is possible to
perform any maintenance tasks. However, some workflows might you discourage to perform
any such actions as they can corrupt the specific workflow and the results
of the whole process, even if they might not visible instantly.

### Installation environment

Keep in mind that the search path for installation hooks `/var/lib/YaST2/hooks/installation`
is read-only. The recommended way of putting the script into the directory is using command
`mount -o bind /some/dir/with/hook/scripts /var/lib/YaST2/hook/installation` .


## Anatomy of hook execution

Let us pretend we are within the installation workflow that has reached the checkpoint
`installation_finish` which means we are right before the system reboot. The workflow
will create and run the hook `installation_finish` which translates to:

1. The hook `installation_finish` is created; log entry saved.
2. The path `/var/lib/YaST2/hooks/installation` is searched for the files matching 
   the pattern `installation_finish_[0-9][0-9]_*`. Search results are logged.
3. Have some files been found, they are executed sequentially by the
   numbers in their name. Results are saved and logged.
4. Hook is considered as failed if one of the executed files returns non-zero exit code.
5. There will be a window displayed with list of all registered hooks with results
   among with files output if any of the file failed.


## Debugging

All important events are logged into the yast log located in `/var/log/YaST2/y2log`.
The installation workflow displays a pop-up at its end if some of the hook files failed.
Beside this no other information is stored for later inspection.


## Checkpoints

The hooks are created and triggered at some specific events - **checkpoints** -
considered important for the workflow. If a hook finds no files to be executed in the
search path, the worfkflow process continues to the next checkpoint. This will repeat
for all checkpoints until the worflow has finished.

The checkpoints are specified separately for every workflow, even within a workflow the
checkpoints may vary, e.g. checkpoints within installation workflow are defined
special for every type of installation (e.g. autoinstallation, manual installation).
Some of the checkpoints are fixed, other may depend on some external definition of
the workflow (for installation the checkpoints depends on the control file definition).


## Installation checkpoints

Installation makes the broadest use of hooks due to its possible customization and
system setup importance. There are at least 4 types of installation workflows which
partly share some of their hook checkpoints, and some have espacially defined for itself:

* manual installation using GUI
* autoinstallation using a profile definition written in xml
* upgrade using GUI
* autoupgrade using a profile definition

Workflows like upgrade, autoupgrade and others are not (yet) in scope of this document.

### General installation hooks

There are four general checkpoints used commonly by all installation workflows. Their
names are:

* installation_start
* installation_finish
* installation_aborted
* installation_failure

Hook files referencing these checkpoints must not have any prefix in their names,
unlike the other hook files specified above. There is no before or after option.

Example of general installation hook script:

* installation_start_[0-9][0-9]_custom_script_name
* installation_finish_[0-9][0-9]_custom_script_name
* installation_aborted_[0-9][0-9]_custom_script_name
* installation_failure_[0-9][0-9]_custom_script_name

### Manual installation checkpoints

Notes:
* checkpoints based on the control file entries which are static
  setup_dhcp
  complex_welcome
  system_analysis
  installation_options
  disk_proposal
  timezone

* checkpoints based on the installation process internals (clients, modules ...)
  which typicaly write the configuration set up in the previous steps


### Autoinstallation checkpoints

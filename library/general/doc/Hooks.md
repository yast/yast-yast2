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
any such actions as they can corrupt the specific workflow or the results
of the whole process, even if they might not be visible instantly.

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

Hooks are created and triggered at some specific events - **checkpoints** -
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
partly share some of their hook checkpoints:

* manual installation using GUI
* autoinstallation using a configuration file written in xml
* upgrade using GUI
* autoupgrade using a configuration file

Workflows like upgrade, autoupgrade and others are not (yet) in scope of this document.

### Main installation checkpoints

There are four main checkpoints used commonly by all installation workflows. Their
names are:

* installation_start
* installation_finish
* installation_aborted
* installation_failure

Hook files referencing these checkpoints must not have any prefix in their names
(there are no **before_** nor **after_** prefixes).

Examples of general installation hook scripts:

* installation_start_[0-9][0-9]_custom_script_name
* installation_finish_[0-9][0-9]_custom_script_name
* installation_aborted_[0-9][0-9]_custom_script_name
* installation_failure_[0-9][0-9]_custom_script_name

### Manual installation checkpoints

These checkpoints trigger hooks during manual installation of the system using
the GUI. Their list may vary according to the control file entries (for more
information see this repository: https://github.com/yast/yast-installation-control)

Hook scripts defined for these checkpoints are being run **before** or **after** the
checkpoint. Thus, the author of the hook files must pick the suitable prefix and
adapt the hook file name.

This is a list of checkpoints which a manual installation might go
through including the main checkpoints in brackets just for completness 
( **Notice:** The list below takes into consideration the basic user workflow for
installing a system. Doing a highly customized installation or adding some
add-ons during the installation will result in a modified list.)

  1. [ installation_start ]
  2. setup_dhcp
  3. complex_welcome
  4. system_analysis
  5. installation_options
  6. disk_proposal
  7. timezone
  8. new_desktop
  9. user_first
  10. initial_installation_proposal
  11. prepareprogress
  12. prepdisk
  13. deploy_image
  14. kickoff
  15. rpmcopy
  16. addon_update_sources
  17. extraxources
  18. save_hardware_status
  19. copy_files_finish
  20. copy_systemfiles_finish
  21. switch_scr_finish
  22. ldconfig_finish
  23. save_config_finish
  24. default_target_finish
  25. desktop_finish
  26. storage_finish
  27. iscsi-client_finish
  28. kernel_finish
  29. x11_finish
  30. proxy_finish
  31. pkg_finish
  32. driver_update1_finish
  33. random_finish
  34. system_settings_finish
  35. bootloader_finish
  36. kdump_finish
  37. yast_inf_finish
  38. network_finish
  39. firewall_stage1_finish
  40. ntp-client_finish
  41. ssh_settings_finish
  42. ssh_service_finish
  43. save_hw_status_finish
  44. users_finish
  45. installation_settings_finish
  46. driver_update2_finish
  47. pre_umount_finish
  48. copy_logs_finish
  49. umount_finish
  50. [ installation_finish ]

If for example the author of a hook file was looking for the point after the partitioning schema
of the disk has been done by the user in order to run some task, he would create a hook file
named ```after_disk_proposal_00_do_something_important``` .


### Autoinstallation checkpoints

Checkpoints for installation via autoyast profile differ from those above by the fact
that there is no graphical guide through the configuration, hence no checkpoints like
those above from 2 to 13. Instead there are these:

* autoinit
* autosetup
* initial_autoinstallation_proposal
* autoimage

Those entries might vary due to different entries in you xml profile which drives
the autoinstallation workflow. The rest of the checkpoints listed above should not much differ.


## Report an issue

In case you followed the notes above and you are still having an issue with executing your
script, please create a bug at http://bugzilla.novell.com.

If you are missing something important in this documentation or you have a question,
please send your query to yast-devel mailing list yast-devel@opensuse.org.





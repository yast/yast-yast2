# Hooks

Hooks is the recommended way of executing custom scripts in the context of
some pre-defined workflow, e.g. installation or update process.


## What is a hook

Hook is a predefined checkpoint at which the workflow will look for files
located in a specific directory matching specific patterns and execute them
sequentially.

The results of the script do not affect the workflow, failed script are registered
and logged as well as the succeeded ones. The author of the hook scripts should
however keep in mind that he should not make any changes in the underlying system
that could negatively impact the parent workflow.


## What is not a hook

Hook is not a system extension (an add-on), but a workflow extension. A hook may be
a part of an add-on product, but should not contain logic and code intended for
the add-on.


## Requirements

A hook file must meet following requirements:

* it must be an executable file
* it must follow the hook [file naming convention](#file-name)
* it must be an [idempotent script](#script-idempotence) that can be executed multiple times
* it must be be a Bash, Ruby, Perl or binary file
* it must not be interactive
* it must be located in the [hook search path](#search-path)
* the code within the script must not access the X session
* some warning about requiring yast library from a Ruby script and using yast 
  modules there


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

The author of a script code must expect the hook to get executed multiple times
during the workflow for various reasons, e.g. the UI may allow the user to go back
and forth in a wizard, or abort the process and start again. 


### Search path

Search path is the the workflow specific directory where the hook scripts are expected
to be stored during its runtime. In general the default search path is 
`var/lib/YaST2/hooks`, but this might be altered by the underlying workflow, e.g. 
installation will search for hook scripts in path `/var/lib/YaST2/hooks/installation`.


## Environment

The hooks are executed with **root** privileges so it is possible to
perform any maintenance tasks. However, some workflows might discourage to perform
any such actions as they can corrupt the specific workflow and the results
of the whole process, even if they might not visible instantly.

### Installation environment

Keep in mind that the search path for installation hooks `/var/lib/YaST2/hooks/installation`
is read-only. The recommended way of putting the script into the directory is using command
`mount -o bind /some/dir/with/hook/scripts /var/lib/YaST2/hook/installation` .


## Checkpoints

The hooks are created and triggered at some specific events - checkpoints -
usually considered important for the workflow. If the hook finds no files to be
executed, the worfkflow process continues its work until the next checkpoint has 
been reached. 


## Anatomy of hook execution

Let us pretend we are within the installation workflow that has reached the checkpoint
`installation_finish` which means we are right before the system reboot. The workflow
will create and run the hook `installation_finish` which translates to:

1. The hook `installation_finish` is created; log entry saved.
2. The path `/var/lib/YaST2/hooks/installation` is searched for the files matching 
   the pattern `installation_finish_[0-9][0-9]_*`. Search results are logged.
3. Have some files been found, they are executed sequentially by the
   numbers in their name. Results are saved and logged.
4. Hook is considered as failed on of the executed files returns non-zero exit code.
5. There will be a window displayed with list of all registered hooks with results
   among with files output if any of the file failed.


## Debugging

All important events are logged into the yast log located in `/var/log/YaST2/y2log`.
The installation workflow displays a pop-up at its end if some of the hook files failed.
Beside this no other information is stored for later inspection.


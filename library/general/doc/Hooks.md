# Hooks

Hooks is officialy supported way of executing any custom scripts in the context of
some closed workflow, e.g. installation, update. Their goals may vary according to
the needs of the user or system admin.


## What is a hook

Hook is a file execution context within some workflow like installation or update.
Hook is a predefined checkpoint at which the process will look for files matching
specific patterns stored in some predefined directory and execute them sequentially.

What is a registered hook?
How to make use of a registered hook?
How is the execution of the script evaluated? (failures are ignored)
How to evaluate the hook script result?
How will the script success/failure result influcence the workflow?


## What is not a hook

Hook is not a system extension (an add-on), but a workflow extension.


## Requirements

A hook file must meet following requirements:

* it must be an executable file
* it must be an [idempotent script](#Script-idempotence) that can be executed multiple times
* it must be be a Bash, Ruby, Perl or binary file
* it must not be interactive
* it must be located in the [hook search path](#Search-path)
* it must follow the hook [file naming convention](#File-naming-convention)
* the code within the script must not access the X session
* some warning about requiring yast library from a Ruby script and using yast 
  modules there


### Script idempotence


### Search path

Is a workflow specific directory (search path)
This predefined hooks directory is workflow specific, installation workflow will be
searching for the files in the directory `/var/lib/YaST2/hooks/installation`. The
default hooks directory is `/var/lib/YaST2/hooks`, but this path might be changed 
by the process managing the hooks, e.g. installation will look for the hook scripts
in the path `/var/lib/YaST2/hooks/installation`.


## Environment

The hooks are executed with **root** privileges so it is possible to
perform any maintenance tasks. However, some workflows might discourage to perform
any such actions as they can corrupt the specific workflow and the results
of the whole process, even if they might not visible instantly.


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
   numbers in their name. Results are saved and logged. Script is considered as failed
   if its exit value is non-zero.
4. There will be a window displayed with list of all registered hooks with results
   and files output if some of the scripts failed.


## Debugging

All important events are logged into the yast log located in `/var/log/YaST2/y2log`.


## Examples

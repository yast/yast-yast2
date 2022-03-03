# Invoking External Commands in YaST

## Best Practice: Yast::Execute

_This is the method to use since about 2018. Don't use SCR .target.bash in new code._

```Ruby
Yast::Execute.on_target!("ls", "-l", arg)
```

or

```Ruby
Yast::Execute.locally!("ls", "-l", arg)
```

This does **not** use a shell to invoke the command, it does a simple `fork()`
/ `execvp()`. It does use `$PATH`, though. See below for security
considerations.

Since this does not use a shell, there is no wildcard file globbing, no I/O
redirection, no pipelined commands, no `||` or `&&`. But all that should be
handled in Ruby code anyway; don't use `| grep | awk` etc. pipelines in YaST
code; Ruby can do all that better and safer.

Under the hood, _Yast::Execute_ uses the [Cheetah Ruby Gem](https://github.com/openSUSE/cheetah).

See also the [Yast::Execute reference documentation](https://www.rubydoc.info/github/yast/yast-yast2/master/Yast/Execute)
and [sources](https://github.com/yast/yast-yast2/blob/master/library/system/src/lib/yast2/execute.rb).


## Legacy Method: SCR .target.bash

Much of the existing YaST code still uses _SCR_ with _.target.bash_.
_This should not be used in new code anymore._

As the name implies, _.target.bash_ uses a bash shell, and it starts external
programs on the _target_, i.e. in a _chroot_ environment (if needed,
i.e. during installation or system upgrade) of the machine that is currently
being installed or configured.


### .target.bash in the Ruby Code

```Ruby
ret_code = SCR.Execute(path(".target.bash"), command)
```

or

```Ruby
result = SCR.Execute(path(".target.bash_output"), command)
ret_code = result["exit"]
stdout = result["stdout"]
stderr = result["stderr"]
```

or

```Ruby
output = SCR.Execute(path(".target.bash_output"), command)["stdout"]
```

_(also available: .target.bash_background, .target.bash_input)_


### .target.bash: The System Agent

This uses the _system agent_ which is registered for all SCR _paths_ starting with `.target`.

<details>

`/usr/share/YaST2/scrconf/target.scr`:

```
.target
`ag_system ()
```

https://github.com/yast/yast-core/blob/master/agent-system/conf/target.scr#L51

This ultimately comes down to using the plain C stdlib `system()` function (`man 3 system`):

https://github.com/yast/yast-core/blob/master/agent-system/src/ShellCommand.cc#L170

In the inst-sys, this uses a _chroot_ jail:

https://github.com/yast/yast-core/blob/master/agent-system/src/ShellCommand.cc#L155
</details>


### .target.bash: Called with a Shell

`system()` executes the command with `/bin/sh` (not the user's login shell!) like this:

```C
execl("/bin/sh", "sh", "-c", command, (char *) 0);
```
(From `man 3 system`)

As a consequence, common shell mechanisms work:

- I/O redirection with `>somewhere` / `<somewhere`, `2>&1`
- command pipelining with `|`
- starting multiple commands with `;`
- logical operators like `||` and `&&`
- file globbing with wildcards
etc.

None of that would work if it were just `fork()` and `exec()` with the binary that is to be called.


## Shell Startup Files

No startup files like `~/.bashrc`, `~/.profile`, `/etc/profile` are executed
because it's not an interactive or a login shell, so there is no danger of
`$PATH` being modified.

<details>

Since `system()` uses `/bin/sh`, the shell that is used can be either _bash_
or, in minimalistic environments, _dash_. It does _not_ take the user's login
shell into account, so other shells like _zsh_, _tcsh_, _csh_, _ksh_ are
irrelevant here.


### Bash Startup Files

_See `man bash`_

For interactive login shells:

- `/etc/profile`
- `~/.bash_profile`
- `~/.bash_login`
- `~/.profile`

For interactive shells:
- `/etc/bash.bashrc`
- `~/.bashrc`

### Dash Startup Files

_See `man dash`_

For login shells:

- `/etc/profile`
- `~/.profile`


### Shell Startup Files used from system()

**None** since a shell started from `system()` is neither a login shell nor an interactive shell.
</details>


## Setting up a Safe $PATH

In the main process, explicitly set the `PATH` environment variable to contain
only known safe locations for executing commands:

```
/sbin:/usr/sbin:/bin:/usr/bin
```

In particular, this should never contain `.` (the current directory) or any
path that _starts_ with `./` or any other relative path, and also no
directories that commonly have write permissions for non-privileged users.


## $PATH in the YaST Start-Up Scripts

All YaST code is started from the `y2start` script (part of package
`yast-ruby-bindings`) which sets up `$PATH` among the first things that it
does:

https://github.com/yast/yast-ruby-bindings/blob/master/src/y2start/y2start#L18
https://github.com/yast/yast-ruby-bindings/blob/master/src/ruby/yast/y2start_helpers.rb#L17

```Ruby
ENV["PATH"] = "/sbin:/usr/sbin:/usr/bin:/bin"
```

This environment is inherited by all child processes, so we have a safe `$PATH` everywhere.


## Verifying $PATH

<details>
This is a little YaST Ruby script to show the value of `$PATH` using different methods:

```Ruby
require "yast"

p = ENV["PATH"]
puts "env PATH: #{p}"

result = Yast::SCR.Execute(Yast.path(".target.bash_output"), "echo $PATH")
stdout = result["stdout"]
puts "echo $PATH: #{stdout}"

result = Yast::SCR.Execute(Yast.path(".target.bash_output"), "printenv | grep '^PATH'")
stdout = result["stdout"]
puts "printenv | grep '^PATH': #{stdout}"

p = `echo $PATH`
puts "with backticks: #{p}"
```

Notice that this intentionally does not have a shell she-bang and no execute
permissions, just like other YaST clients. The way to start this is:

```
/usr/lib/YaST2/bin/y2start ./yast_path_target_bash.rb qt
```

The output:

```
env PATH: /sbin:/usr/sbin:/usr/bin:/bin
echo $PATH: /sbin:/usr/sbin:/usr/bin:/bin
printenv | grep '^PATH': PATH=/sbin:/usr/sbin:/usr/bin:/bin
with backticks: /sbin:/usr/sbin:/usr/bin:/bin
```

Executing similar code in `irb` to show that the shell environment (without
using `y2start`) does indeed have a different $PATH:

```irb
[sh @ balrog-tw-dev] ~ 2 % irb
irb(main):001:0> require "yast"
=> true
irb(main):002:0> Yast::SCR.Execute(Yast.path(".target.bash_output"), "echo $PATH")["stdout"]
=> ".:/home/sh/util:/home/sh/perl:/usr/local/bin:/usr/lib64/qt5/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/X11R6/bin:/opt/gnome/bin:/usr/share/YaST2/data/devtools/bin"
irb(main):003:0>
```
</details>


## Use Absolute Paths or Rely on $PATH?

For calling external programs that are in any of the well-known secure
locations (`/bin`, `/usr/bin`, `/sbin`, `usr/sbin`), use only the name without
the path: `cp`, not `/bin/cp`; `mkdir`, not `/bin/mkdir` etc.: That makes it
safe against being moved from one directory to another, e.g. during the
_usr-merge_ around 2022 where commands were moved from `/bin` to `/usr/bin` and
from `/sbin` to `/usr/sbin`.

Even if there are compatibility symlinks (e.g. `/bin/mkdir` -> `/usr/bin/mkdir`
or in other releases `/bin` -> `/usr/bin`), there is no guarantee that they
will be there forever.

For calling external programs in other directories like
`/usr/lib/YaST2/bin/y2start`, the full path still needs to be used, of course.


## Other Methods of Calling External Programs

The standard Ruby methods should not be used in any YaST code anyway to make
sure it supports a _chroot_ environment that works inside the mounted
installation target and affects paths there, not in the inst-sys (which is
largely mounted read-only anyway).

But still, those standard Ruby methods also get the same `$PATH`, so they are
safe as well:

- Using backticks (see example above)
- Using Ruby `system()`
- Ruby gems using any of those


## Further Reading

- [YaST Security Audit Lessons Learned](https://github.com/yast/yast.github.io/issues/172)

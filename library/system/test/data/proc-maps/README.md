# Data for Testing SharedLibInfo

The files in this directory are the content of `/proc/$pid/maps` of (mostly
y2base) processes when different shared libraries were loaded, in particular
YaST UI plug-ins:

- proc-maps-qt:          Qt UI
- proc-maps-qt-pkg:      Qt UI + Qt-Pkg (YQPackageSelector) extension
- proc-maps-qt-graph:    Qt UI + Qt-Graph (GraphViz) extension
- proc-maps-ncurses:     NCurses UI
- proc-maps-ncurses-pkg: NCurses UI + NCurses-Pkg (NCPackageSelector) extension
- proc-maps-no-ui:       No YaST UI at all, just a simple shell process


## How to Generate those Files

- Start any simple YaST process; the UI examples from ycp-ui-bindings are
  totally sufficient:

      cd ycp-ui-bindings/examples
      /usr/lib/YaST2/bin/y2start ./HelloWorld.rb qt

  or

      /usr/lib/YaST2/bin/y2start ./HelloWorld.rb ncurses

- For -pkg extensions:

      /usr/lib/YaST2/bin/y2start ./PackageSelector-empty.rb qt
      /usr/lib/YaST2/bin/y2start ./PackageSelector-empty.rb ncurses

- For the qt-graph extension:

      /usr/lib/YaST2/bin/y2start ./Graph1.rb qt

- Leave the y2base process running (!)

- Check its PID from the y2log (in your home directory!):

      tail ~/.y2log

      2021-09-07 16:04:34 <1> localhost.localdomain(6921) [qt-ui] YQGraphPluginStub.cc...
                                                    ^^^^
                                                    PID

- Get its `maps` file:

      cat /proc/6921/maps >/tmp/my-maps-file

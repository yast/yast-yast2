#
# Makefile.am for yast2/scripts
#

sbin_SCRIPTS = yast2 save_y2logs

ybin_SCRIPTS = yast2-funcs

completiondir =  /usr/share/bash-completion/completions/
completion_DATA = completions/yast2

EXTRA_DIST = $(sbin_SCRIPTS) $(ybin_SCRIPTS) $(completion_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)$(ybindir)
# symlink to call yast in ncurses
	ln -snf yast2 $(DESTDIR)$(sbindir)/yast
# backward compatibility
	install -d -m 755 $(DESTDIR)/sbin
	ln -snf $(sbindir)/yast2 $(DESTDIR)/sbin/yast2
	ln -snf $(sbindir)/yast2 $(DESTDIR)/sbin/yast
# symlink to have completions also for 'yast'
	ln -snf yast2 $(DESTDIR)/$(completiondir)/yast

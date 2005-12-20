#
# Makefile.am for yast2/scripts
#

sbin_SCRIPTS = yast2 save_y2logs

ybin_SCRIPTS = yast2 yast2-funcs check-all-syntax

completiondir = $(sysconfdir)/bash_completion.d
completion_DATA = yast2-completion.sh

EXTRA_DIST = $(sbin_SCRIPTS) $(ybin_SCRIPTS) $(completion_DATA)

install-data-local:
	install -d -m 755 $(DESTDIR)$(ybindir)
	ln -snf yast2 $(DESTDIR)$(sbindir)/zast2
	ln -snf yast2 $(DESTDIR)$(sbindir)/YaST2
	ln -snf yast2 $(DESTDIR)$(sbindir)/ZaST2
	ln -snf yast2 $(DESTDIR)$(sbindir)/yast
	ln -snf yast2 $(DESTDIR)$(sbindir)/zast
	ln -snf yast2 $(DESTDIR)$(sbindir)/YaST
	ln -snf yast2 $(DESTDIR)$(sbindir)/ZaST

#
# Makefile.am for yast2/scripts
#

sbindir = /sbin
sbin_SCRIPTS = yast2

ybin_SCRIPTS = yast2 yast2_kde yast2-funcs

EXTRA_DIST = $(sbin_SCRIPTS) $(ybin_SCRIPTS)

install-data-local:
	install -d -m 755 $(DESTDIR)$(ybindir)
	ln -snf yast2 $(DESTDIR)$(sbindir)/zast2
	ln -snf yast2 $(DESTDIR)$(sbindir)/YaST2
	ln -snf yast2 $(DESTDIR)$(sbindir)/ZaST2
	ln -snf yast2 $(DESTDIR)$(sbindir)/yast
	ln -snf yast2 $(DESTDIR)$(sbindir)/zast
	ln -snf yast2 $(DESTDIR)$(sbindir)/YaST
	ln -snf yast2 $(DESTDIR)$(sbindir)/ZaST

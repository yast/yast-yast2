#
# Makefile.am for yast2/scripts
#

sbindir = /sbin
sbin_SCRIPTS = yast2

ybin_SCRIPTS = YaST2 yast2 yast2_kde yast2-funcs

EXTRA_DIST = $(sbin_SCRIPTS) $(ybin_SCRIPTS)

install-data-local:
	install -d -m 755 $(DESTDIR)$(ybindir)
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/zast2
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaST2
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaST2
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/yast
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/zast
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaST
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaST
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/zastì
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/ZaSTì
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/YaSTì
	ln -snf $(sbindir)/yast2 $(DESTDIR)$(sbindir)/yastì

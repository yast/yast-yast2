#
# Makefile.am for yast2/doc/autodocs
#

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../library/*/*.ycp $(srcdir)/../../library/*/src/*.ycp
	@ybindir@/ycpdoc -d. $(srcdir)/../../library/*/*.ycp $(srcdir)/../../library/*/src/*.ycp

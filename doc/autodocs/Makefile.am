#
# Makefile.am for yast2/doc/autodocs
#

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../menu/*.ycp $(srcdir)/../../library/modules/*.ycp
	@ybindir@/ycpdoc -d. $(srcdir)/../../menu/*.ycp $(srcdir)/../../library/modules/*.ycp

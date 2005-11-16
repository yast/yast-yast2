# Makefile.am for yast2/doc/autodocs

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../library/*/*.ycp
	${YCPDOC} -d. $(srcdir)/../../library/*/*.ycp

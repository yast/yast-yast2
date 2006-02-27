# Makefile.am for YCP module .../doc/autodocs

htmldir = @docdir@/cwm/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp
	${YCPDOC} -d. $(srcdir)/../../src/*.ycp


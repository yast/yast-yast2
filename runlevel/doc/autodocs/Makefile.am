# Makefile.am for YCP module .../doc/autodocs

htmldir = @docdir@/autodocs

html_DATA = index.html $(wildcard *.html)
CLEANFILES = $(html_DATA)

index.html: $(srcdir)/../../src/*.ycp
	@ybindir@/ycpdoc -d. $(srcdir)/../../src/*.ycp

#
# Makefile.am for xml/module/doc/autodocs
#

htmldir = $(docdir)/autodocs

index.html: $(srcdir)/../../src/*.ycp 
	@ybindir@/ycpdoc -d. $(srcdir)/../../src/*.ycp

html_DATA = index.html $(wildcard *.html)

CLEANFILES = $(html_DATA)

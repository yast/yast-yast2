# Makefile.am for YCP module .../doc/autodocs
#

STYLESHEET_YCPDOC=$(ydatadir)/docbook/stylesheets/ycpdoc.xsl
htmldir = $(docdir)/types/autodocs

html_DATA = index.html $(wildcard *.html)  

xml_files = $(wildcard *.xml)
CLEANFILES = $(html_DATA) ycpdoc.xml  $(xml_file)


index.html: $(srcdir)/../../src/*.ycp
	@ybindir@/ycpdoc -f xml -f html -d. $(srcdir)/../../src/*.ycp

reference: ycpdoc.xml
	xsltproc --xinclude $(STYLESHEET_YCPDOC) $<

all-local: reference

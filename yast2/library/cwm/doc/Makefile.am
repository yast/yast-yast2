# Makefile.am for YCP module .../doc

SUBDIRS = autodocs

htmldir = $(docdir)/cron

html_DATA = # cwm.html

EXTRA_DIST = $(html_DATA)

# blah?

SOURCES = $(wildcard *.xml)

ps: cwm.ps

pdf: cwm.pdf

html: cwm.html

dvi: cwm.dvi

cwm.dvi: $(SOURCES)
	db2dvi cwm.xml

cwm.ps: $(SOURCES)
	db2ps cwm.xml

cwm.pdf: $(SOURCES)
	db2pdf cwm.xml

cwm.html: $(SOURCES)
	db2html cwm.xml
	chmod -R og+rX cwm

check-manual: cwm.xml
	xmllint --nonet --noout $^

# Makefile.am for YCP module .../doc

include ${srcdir}/docbook-xmlto.ami

SUBDIRS = autodocs

htmldir = $(docdir)/cwm

html_DATA = # cwm.html

EXTRA_DIST = $(html_DATA) docbook-*.ami

DOCBOOK_MAIN = cwm.xml
DOCBOOK_FILES = $(wildcard *.xml)

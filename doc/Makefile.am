#
# Makefile.am for y2c_network/doc
#

SUBDIRS = autodocs examples screenshots

htmldir = $(docdir)

doc_DATA =
html_DATA =
man_MANS = yast2.8 yast.8

yast.8:
	ln -snf yast2.8 yast.8

EXTRA_DIST = $(doc_DATA) $(html_DATA) $(man_MANS)

#
# Makefile.am for yast2/y2menu
#

AM_CXXFLAGS = -DHAVE_NCURSES -DLOCALEDIR=\"${localedir}\"	\
	-DCONFIGDIR=\"$(configdir)\"

ybin_PROGRAMS = y2menu

y2menu_SOURCES = parsecfg.cc parseyast.cc util.cc yast2.cc	\
	yastmenu.cc colors.h parseyast.h yast.h yastfunc.h	\
	myintl.cc myintl.h

y2menu_LDADD = -lncurses

ydata_DATA = y2menu-color

EXTRA_DIST = $(ydata_DATA)

#
# Makefile.am for yast2/y2menu
#

AM_CXXFLAGS = -DLOCALE -DHAVE_NCURSES

ybin_PROGRAMS = y2menu

y2menu_SOURCES = parsecfg.cc parseyast.cc util.cc yast2.cc	\
	yastmenu.cc colors.h parseyast.h yast.h yastfunc.h

y2menu_LDADD = -lncurses

y2menu_LDFLAGS =

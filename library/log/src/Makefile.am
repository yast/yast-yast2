# Sources for yast2

module_DATA = \
  modules/ALog.rb \
  modules/LogView.rb \
  modules/LogViewCore.rb

ylibdir = @ylibdir@/log
ylib_DATA = \
  lib/log/y2logger.rb

EXTRA_DIST = $(module_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common

module_DATA = \
  modules/systemd_socket.rb \
  modules/systemd_service.rb \
  modules/systemd_target.rb

ylibdir = @ylibdir@/yast2
ylib_DATA = \
  lib/yast2/service_configuration.rb \
  lib/yast2/systemctl.rb \
  lib/yast2/systemd_unit.rb

EXTRA_DIST = $(module_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common

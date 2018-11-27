ylibdir = @ylibdir@/yast2
ylib_DATA = \
  lib/yast2/compound_service.rb \
  lib/yast2/service_widget.rb \
  lib/yast2/systemctl.rb \
  lib/yast2/system_service.rb \
  lib/yast2/systemd.rb

systemddir = @ylibdir@/yast2/systemd
systemd_DATA = \
  lib/yast2/systemd/unit.rb \
  lib/yast2/systemd/unit_prop_map.rb \
  lib/yast2/systemd/unit_properties.rb \
  lib/yast2/systemd/unit_installation_properties.rb \
  lib/yast2/systemd/service.rb \
  lib/yast2/systemd/socket.rb \
  lib/yast2/systemd/target.rb \
  lib/yast2/systemd/socket_finder.rb

EXTRA_DIST = $(ylib_DATA) $(systemd_DATA)

include $(top_srcdir)/Makefile.am.common

# Sources for yast2

module_DATA = \
  modules/Linuxrc.rb \
  modules/Message.rb \
  modules/Misc.rb \
  modules/Icon.rb \
  modules/Call.rb \
  modules/AsciiFile.rb \
  modules/ContextMenu.rb \
  modules/Crash.rb \
  modules/FileUtils.rb \
  modules/Arch.rb \
  modules/Mode.rb \
  modules/Directory.rb \
  modules/Encoding.rb \
  modules/CustomDialogs.rb \
  modules/Distro.rb \
  modules/XVersion.rb \
  modules/Summary.rb \
  modules/UIHelper.rb \
  modules/DontShowAgain.rb \
  modules/Report.rb \
  modules/ValueBrowser.rb \
  modules/Event.rb \
  modules/Label.rb \
  modules/Assert.rb \
  modules/OSRelease.rb \
  modules/PackagesProposal.rb \
  modules/Popup.rb \
  modules/MailAliases.rb \
  modules/Stage.rb \
  modules/MailTable.pm \
  modules/MailTableInclude.pm \
  modules/Hooks.rb

scrconf_DATA = \
  scrconf/cfg_hotplug.scr \
  scrconf/proc_meminfo.scr \
  scrconf/etc_sysctl_conf.scr \
  scrconf/cfg_sysctl.scr \
  scrconf/etc_inittab.scr \
  scrconf/cfg_apache2.scr \
  scrconf/cfg_features.scr \
  scrconf/etc_ssh_sshd_config.scr \
  scrconf/cfg_displaymanager.scr \
  scrconf/cfg_yast2.scr \
  scrconf/cfg_xversion.scr \
  scrconf/yast2_groups.scr \
  scrconf/etc_fstab.scr \
  scrconf/cfg_cron.scr \
  scrconf/cfg_suseconfig.scr \
  scrconf/etc_login_defs.scr \
  scrconf/cfg_policykit.scr \
  scrconf/system_freespace.scr \
  scrconf/run_ifconfig.scr \
  scrconf/cfg_apache.scr \
  scrconf/cfg_services.scr \
  scrconf/anyxml.scr \
  scrconf/yast2_desktop.scr \
  scrconf/proc_mounts.scr \
  scrconf/proc_modules.scr \
  scrconf/cfg_ypserv.scr \
  scrconf/cfg_security.scr

agent_SCRIPTS = \
  servers_non_y2/ag_anyxml \
  servers_non_y2/ag_freespace

ydata_DATA = \
  data/country.ycp \
  data/country_long.ycp

fillup_DATA = \
  fillup/sysconfig.yast2

ylibinstallationdir = "${yast2dir}/lib/installation"
ylibinstallation_DATA = \
  lib/installation/auto_client.rb \
  lib/installation/finish_client.rb \
  lib/installation/proposal_client.rb

ylibuidir = "${yast2dir}/lib/ui"
ylibui_DATA = \
  lib/ui/dialog.rb \
  lib/ui/installation_dialog.rb \
  lib/ui/event_dispatcher.rb \
  lib/ui/greasemonkey.rb \
  lib/ui/service_status.rb \
  lib/ui/text_helpers.rb \
  lib/ui/widgets.rb

ylibyast2dir = "${yast2dir}/lib/yast2"
ylibyast2_DATA = \
  lib/yast2/feedback.rb \
  lib/yast2/popup.rb \
  lib/yast2/popup_rspec.rb

EXTRA_DIST = $(module_DATA) $(client_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(ydata_DATA) $(fillup_DATA) $(ylibinstallation_DATA) $(ylibui_DATA) $(ylibyast2_DATA)


include $(top_srcdir)/Makefile.am.common

# Sources for yast2

module_DATA = \
  modules/WizardHW.rb \
  modules/DialogTree.rb \
  modules/CWM.rb \
  modules/CWMTsigKeys.rb \
  modules/CWMTable.rb \
  modules/CWMServiceStart.rb \
  modules/CWMTab.rb \
  modules/TablePopup.rb

ylibdir = @ylibdir@/cwm
ylib_DATA = \
  lib/cwm/abstract_widget.rb \
  lib/cwm/custom_widget.rb \
  lib/cwm/page.rb \
  lib/cwm/pager.rb \
  lib/cwm/tabs.rb \
  lib/cwm/tree.rb \
  lib/cwm/tree_pager.rb \
  lib/cwm/widget.rb


EXTRA_DIST = $(module_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common

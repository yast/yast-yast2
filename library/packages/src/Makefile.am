# Sources for yast2

module_DATA = \
  modules/PackageCallbacks.rb \
  modules/SignatureCheckDialogs.rb \
  modules/PackageLock.rb \
  modules/PackagesUI.rb \
  modules/PackageAI.rb \
  modules/Slides.rb \
  modules/PackageCallbacksInit.rb \
  modules/Product.rb \
  modules/SlideShow.rb \
  modules/SignatureCheckCallbacks.rb \
  modules/PackageKit.rb \
  modules/PackageSystem.rb \
  modules/Package.rb

yncludedir = @yncludedir@/packages
ynclude_DATA = \
  include/packages/common.rb

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

include $(top_srcdir)/Makefile.am.common
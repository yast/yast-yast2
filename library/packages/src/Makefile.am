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

ylibdir = "${yast2dir}/lib/packages"
ylib_DATA = \
  lib/packages/commit_result.rb \
  lib/packages/dummy_callbacks.rb \
  lib/packages/file_conflict_callbacks.rb \
  lib/packages/package_downloader.rb \
  lib/packages/package_extractor.rb \
  lib/packages/product.rb \
  lib/packages/repository.rb \
  lib/packages/update_message.rb \
  lib/packages/update_messages_view.rb

EXTRA_DIST = $(module_DATA) $(ynclude_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common

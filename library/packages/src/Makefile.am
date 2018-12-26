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
  lib/packages/update_message.rb \
  lib/packages/update_messages_view.rb

y2packagerdir = "${yast2dir}/lib/y2packager"
y2packager_DATA = \
	lib/y2packager/license.rb \
	lib/y2packager/licenses_handlers.rb \
	lib/y2packager/licenses_fetchers.rb \
	lib/y2packager/package.rb \
	lib/y2packager/product.rb \
	lib/y2packager/product_license.rb \
	lib/y2packager/product_reader.rb \
	lib/y2packager/product_sorter.rb \
	lib/y2packager/product_upgrade.rb \
	lib/y2packager/release_notes.rb \
	lib/y2packager/release_notes_content_prefs.rb \
	lib/y2packager/release_notes_reader.rb \
	lib/y2packager/release_notes_store.rb

y2rns_fetchersdir = "${yast2dir}/lib/y2packager/release_notes_fetchers"
y2rns_fetchers_DATA = \
	lib/y2packager/release_notes_fetchers/base.rb \
	lib/y2packager/release_notes_fetchers/rpm.rb \
	lib/y2packager/release_notes_fetchers/url.rb

y2licenses_fetchersdir = "${yast2dir}/lib/y2packager/licenses_fetchers"
y2licenses_fetchers_DATA = \
	lib/y2packager/licenses_fetchers/base.rb \
	lib/y2packager/licenses_fetchers/libzypp.rb \
	lib/y2packager/licenses_fetchers/rpm.rb

y2licenses_handlersdir = "${yast2dir}/lib/y2packager/licenses_handlers"
y2licenses_handlers_DATA = \
	lib/y2packager/licenses_handlers/base.rb \
	lib/y2packager/licenses_handlers/libzypp.rb

EXTRA_DIST = $(module_DATA) $(ynclude_DATA) $(ylib_DATA) $(y2packager_DATA) $(y2rns_fetchers_DATA) \
						 $(y2licenses_fetchers_DATA) $(y2licenses_handlers_DATA)

include $(top_srcdir)/Makefile.am.common

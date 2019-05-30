require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["data/XVersion"] = File.join(Packaging::Configuration::DESTDIR, "/etc/YaST2/")
  conf.install_locations["scripts/yast2-completion.sh"] = File.join(Packaging::Configuration::DESTDIR, "/usr/share/bash-completion/completions")
  conf.install_locations["scripts/yast2-funcs"] = File.join(Packaging::Configuration::YAST_LIB_DIR, "/bin/")
  conf.install_locations["scripts/yast2"] = File.join(Packaging::Configuration::DESTDIR, "/usr/sbin/")
  conf.install_locations["scripts/yast"] = File.join(Packaging::Configuration::DESTDIR, "/usr/sbin/")
  conf.install_locations["scripts/legacy_sbin/*"] = File.join(Packaging::Configuration::DESTDIR, "/sbin/")
  conf.install_locations["scripts/save_y2logs"] = File.join(Packaging::Configuration::DESTDIR, "/usr/sbin/")
  conf.install_locations["COPYING"] = conf.install_doc_dir
  conf.install_locations["doc/yast*.8"] = File.join(Packaging::Configuration::DESTDIR, "/usr/share/man/man8/")
  conf.install_locations["library/desktop/groups/*.desktop"] = File.join(Packaging::Configuration::DESTDIR, "/usr/share/applications/YaST2/groups/")
  conf.install_locations["library/general/hooks/README.md"] = File.join(Packaging::Configuration::DESTDIR, "/var/lib/YaST2/hooks/")
end

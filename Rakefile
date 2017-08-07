require "yast/rake"

Yast::Tasks.submit_to :casp10

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
end

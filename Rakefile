require "yast/rake"

Yast::Tasks.submit_to :sle15

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
end

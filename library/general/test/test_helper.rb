
top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

def set_root_path(directory)
  check_version = false
  handle = Yast::WFM.SCROpen("chroot=#{directory}:scr", check_version)
  Yast::WFM.SCRSetDefault(handle)
end

def reset_root_path
  Yast::WFM.SCRClose(Yast::WFM.SCRGetDefault)
end

require "rspec"

# Helpers for stubbing several agent operations.
module SCRStub
  # Shortcut for generating Yast::Path objects
  #
  # @param route [String] textual representation of the path
  # @return [Yast::Path] the corresponding Path object
  def path(route)
    Yast::Path.new(route)
  end

  # Encapsulates subsequent SCR calls into a chroot.
  #
  # Raises an exception if something goes wrong.
  #
  # @param [#to_s] directory to use as '/' for SCR calls
  def change_scr_root(directory)
    # On first call, store the default handler in the stack
    @scr_handles ||= [Yast::WFM.SCRGetDefault]

    check_version = false
    handle = Yast::WFM.SCROpen("chroot=#{directory}:scr", check_version)
    raise "Error creating the chrooted scr instance" if handle < 0

    @scr_handles << handle
    Yast::WFM.SCRSetDefault(handle)
  end

  # Resets the SCR calls to prior behaviour, closing the SCR instance open by
  # the last call to #change_scr_root.
  #
  # Raises an exception if #change_scr_root has not been called before or if the
  # corresponding instance has already been closed.
  #
  # @see #change_scr_root
  def reset_scr_root
    if @scr_handles.nil? || @scr_handles.size < 2
      raise "The SCR instance cannot be closed, it's the last remaining one"
    end

    default_handle = Yast::WFM.SCRGetDefault
    if default_handle != @scr_handles.pop
      raise "Error closing the chrooted SCR instance, it's not the current default one"
    end

    Yast::WFM.SCRClose(default_handle)
    Yast::WFM.SCRSetDefault(@scr_handles.last)
  end
end

RSpec.configure do |c|
  c.include SCRStub
end

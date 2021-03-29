# typed: true
# YaST packages module
module Packages
  # Represents an update message from libzypp.
  #
  #
  # @see https://doc.opensuse.org/projects/libzypp/HEAD/classzypp_1_1ZYppCommitResult.html#ae6883415d94d4728e3de0dc9c7c58fd5
  # @!attribute [r] solvable
  #   @return [String] Name of the solvable libzypp element (usually the package's name).
  # @!attribute [r] text
  #   @return [String] Message's text.
  # @!attribute [r] installation_path
  #   @return [String] Path to the file which contains the message in the installed system.
  # @!attribute [r] current_path
  #   @return [String] Path to the file which contains the message in the running system.
  #                    While running inst-sys, it will differ from installation_path.
  UpdateMessage = Struct.new(:solvable, :text, :installation_path, :current_path)
end

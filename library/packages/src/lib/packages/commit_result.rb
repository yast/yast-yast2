# typed: true
require "packages/update_message"

module Packages
  # Commit results coming from libzypp
  class CommitResult
    attr_reader :committed, :successful, :failed, :remaining, :srcremaining, :update_messages

    class << self
      # Construct an instance taking as input the Pkg.Commit or Pkg.PkgCommit output
      #
      # Pkg.Commit and Pkg.PkcCommit return an array with the following
      # elements: [successful, failed, remaining, srcremaining, update_messages].
      #
      # @param result [Array] Result as returned by Pkg.Commit and Pkg.PkgCommit
      def from_result(result)
        messages = build_update_messages(result[4] || [])
        new(result[0], result[1], result[2], result[3], messages)
      end

      # Convert an array of hash into an array of UpdateMessage objects
      #
      # Each hash contains the following keys/values:
      #
      # * solvable:         solvable name (usually package names).
      # * text:             message text.
      # * installationPath: path to the libzypp's file containing the message
      #                     after installation.
      # * currentPath:      path to the libzypp's file containing the message
      #                     currently. It will differ from installationPath
      #                     when running inst-sys.
      #
      # @param messages [Array<Hash>] Hash representing a message from libzypp.
      # @return [Array<Packager::UpdateMessage>] List of update messages
      def build_update_messages(messages)
        messages.map do |msg|
          Packages::UpdateMessage.new(msg["solvable"], msg["text"],
            msg["installationPath"], msg["currentPath"])
        end
      end
    end

    # Constructor
    #
    # @param successful      [Integer] Number of commited resolvables
    # @param failed          [Array]   List of resolvables with error
    # @param remaining       [Array]   List of remaining resolvables (due to wrong media)
    # @param srcremaining    [Array]   List of kind:source remaining resolvables (due to wrong media)
    # @param update_messages [Array<Hash>] List of libzypp update messages.
    #                                      Check .build_update_messages for more details.
    #
    # @see build_update_messages
    def initialize(successful, failed, remaining, srcremaining, update_messages)
      @successful = successful
      @failed = failed || []
      @remaining = remaining || []
      @srcremaining = srcremaining || []
      @update_messages = update_messages || []
    end
  end
end

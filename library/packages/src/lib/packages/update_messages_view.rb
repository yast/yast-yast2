require "yast"

module Packages
  # This class converts a set of commit results into string representations.
  #
  # At this time, richtext is the only provided conversion.
  class UpdateMessagesView
    include Yast::I18n
    extend Yast::I18n

    def initialize(commit_results)
      Yast.import "String"
      textdomain "base"
      @commit_results = commit_results
    end

    # Convert a list of messages into richtext
    #
    # @param messages [Array<UpdateMessage>] List of messages
    # @return [String] Richtext representation of the list of messages
    def richtext
      text = "<h1>#{_("Packages messages")}</h1>"
      text << @commit_results.map { |m| message_to_richtext(m) }.join("<hr>")
    end

  private

    # Convert one message to richtext
    #
    # @return [String] Message converted to richtext
    def message_to_richtext(message)
      location = format(_("This message will be available at %s"),
        Yast::String.EscapeTags(message.installation_path))
      "<h2>#{Yast::String.EscapeTags(message.solvable)}</h2><p><em>#{location}</em></p>" \
        "<br>#{message.text.strip.gsub("\n", "<br>")}"
    end
  end
end

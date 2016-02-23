require "yast"

module Packages
  # This class converts a set of libzypp update messages into string
  # representations.
  #
  # At this time, richtext is the only provided conversion.
  class UpdateMessagesView
    include Yast::I18n
    extend Yast::I18n

    def initialize(messages)
      Yast.import "String"
      textdomain "base"
      @messages = messages
    end

    # Convert a list of messages into richtext
    #
    # @param messages [Array<UpdateMessage>] List of messages
    # @return [String] Richtext representation of the list of messages
    def richtext
      text = "<h1>#{_("Packages notifications")}</h1>\n" \
        "<p>#{_("You have notifications from the following packages:")}</p>"
      text << richtext_toc(@messages) if @messages.size > 1
      text << @messages.map { |m| message_to_richtext(m) }.join("<hr>")
    end

  private

    # Convert one message to richtext
    #
    # @return [String] Message converted to richtext
    def message_to_richtext(message)
      location = format(_("This message will be available at %s"),
        Yast::String.EscapeTags(message.installation_path))
      content = message.text.strip.gsub("\n\n", "</p><p>").gsub("\n", "<br>")

      "<h2>#{Yast::String.EscapeTags(message.solvable)}</h2>" \
        "<p><em>#{location}</em></p>" \
        "<p>#{content}</p>"
    end

    # Return a richtext list of package names to be used as table of contents
    #
    # @return [String] List of package names
    def richtext_toc(messages)
      names = messages.map { |m| Yast::String.EscapeTags(m.solvable) }
      "<ul><li>#{names.join("</li>\n<li>")}</li></ul>\n"
    end
  end
end

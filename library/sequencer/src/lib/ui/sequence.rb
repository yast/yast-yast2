require "yast"
Yast.import "Sequencer"

# FIXME: once the API is reviewed, move this to yast-yast2
module UI
  # A {UI::Sequence} is an object-oriented interface for the good old
  # {Yast::SequencerClass Yast::Sequencer}.
  # In the simple case it runs a sequence of dialogs
  # connected by Back and Next buttons.
  class Sequence
    include Yast::I18n

    # A drop-in replacement for
    # {Yast::SequencerClass#Run Yast::Sequencer.Run}
    def self.run(aliases, sequence)
      Yast::Sequencer.Run(aliases, sequence)
    end

    # A replacement for
    # {Yast::SequencerClass#Run Yast::Sequencer.Run}
    # but smarter:
    # - auto :abort (see {#abortable})
    # - *aliases* are assumed to be method names if unpecified
    #   (see {#from_methods})
    def run(aliases: nil, sequence:)
      aliases = from_methods(sequence) if aliases.nil?
      self.class.run(aliases, abortable(sequence))
    end

    # Add !{abort: :abort} transitions if missing
    # (an :abort from a dialog should :abort the whole sequence)
    def abortable(sequence_hash)
      sequence_hash.map do |name, destination|
        if name == "ws_start"
          [name, destination]
        else
          [name, { abort: :abort }.merge(destination)]
        end
      end.to_h
    end

    # Make `aliases` from `sequence_hash` assuming there is a method
    # for each alias.
    # @return [Hash{id => Proc}] aliases
    def from_methods(sequence_hash)
      sequence_hash.keys.map do |name|
        next nil if name == "ws_start"
        if self.class.skip_stack?(name)
          [name, [method(name), true]]
        else
          [name, method(name)]
        end
      end.compact.to_h
    end

    class << self
      # Declare that a method is skipped when going :back,
      # useful for noninteractive steps.
      # (also see Yast::SequencerClass#WS_special)
      def skip_stack(method_symbol)
        @skip_stack ||= {}
        @skip_stack[method_symbol] = true
      end

      def skip_stack?(name)
        @skip_stack ||= {}
        @skip_stack[name.to_sym]
      end
    end
  end
end

require_relative "test_helper"
require "ui/sequence"

describe UI::Sequence do
  describe "#abortable" do
    it "adds aborting edges where missing" do
      old = {
        "ws_start" => "read",
        "read"     => { next: "process" },
        "process"  => { next: "write" },
        "write"    => { next: :next }
      }
      new = {
        "ws_start" => "read",
        "read"     => { abort: :abort, next: "process" },
        "process"  => { abort: :abort, next: "write" },
        "write"    => { abort: :abort, next: :next }
      }

      expect(subject.abortable(old)).to eq(new)
    end

    it "keeps existing aborting edges" do
      old = {
        "ws_start" => "read",
        "process"  => { abort: :back, next: "write" },
        "write"    => { next: :next }
      }
      new = {
        "ws_start" => "read",
        "process"  => { abort: :back, next: "write" },
        "write"    => { abort: :abort, next: :next }
      }

      expect(subject.abortable(old)).to eq(new)
    end
  end

  describe "#from_methods" do
    class TestSequence < UI::Sequence
      def skipped
      end
      skip_stack :skipped

      def first
      end

      def second
      end
    end
    subject { TestSequence.new }

    class UnrelatedTestSequence < UI::Sequence
      def first
      end
      skip_stack :first
    end

    it "defines the aliases from instance methods" do
      seq = {
        "ws_start" => "skipped",
        "skipped"  => { next: "first" },
        "first"    => { next: "second" },
        "second"   => { next: :next }
      }
      wanted = {
        "skipped" => [subject.method(:skipped), true],
        "first"   => subject.method(:first),
        "second"  => subject.method(:second)
      }

      expect(subject.from_methods(seq)).to eq(wanted)
    end

    it "does not confuse skip_stack across classes" do
      subj = UnrelatedTestSequence.new
      seq = {
        "ws_start" => "first",
        "first"    => { next: :next }
      }
      wanted = {
        "first" => [subj.method(:first), true]
      }

      expect(subj.from_methods(seq)).to eq(wanted)
    end
  end
end

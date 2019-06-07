# typed: false
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
      class TestSequenceA < UI::Sequence
        def doit
        end
        skip_stack :doit
      end

      class TestSequenceB < UI::Sequence
        def doit
        end
      end

      seq = {
        "ws_start" => "doit",
        "doit"     => { next: :next }
      }

      a = TestSequenceA.new
      b = TestSequenceB.new
      wanted_a = {
        "doit" => [a.method(:doit), true]
      }
      wanted_b = {
        "doit" => b.method(:doit)
      }

      expect(a.from_methods(seq)).to eq(wanted_a)
      expect(b.from_methods(seq)).to eq(wanted_b)
    end
  end
end

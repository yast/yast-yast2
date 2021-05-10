require "tempfile"
require "yaml"

require_relative "../test_helper"
require "installation/installation_info"

describe Installation::InstallationInfo do
  # create a new anonymous subclass inheriting from the singleton class,
  # this ensures we use a fresh instance for each test and we do not modify
  # the global singleton instance
  subject { Class.new(Installation::InstallationInfo).instance }

  describe "#add" do
    it "remembers the callback block" do
      expect { subject.add("test") { puts "foo" } }.to change { subject.included?("test") }
        .from(false).to(true)
    end

    it "does not save missing block" do
      subject.add("test")

      expect(subject.included?("test")).to eq(false)
    end
  end

  describe "#included?" do
    it "returns true for a defined callback name" do
      subject.add("test") { puts "foo" }

      expect(subject.included?("test")).to eq(true)
    end

    it "returns false for an undefined callback name" do
      expect(subject.included?("foo")).to eq(false)
    end
  end

  describe "#write" do
    before do
      allow(File).to receive(:write)
      allow(FileUtils).to receive(:mkdir_p)
    end

    it "evaluates all callbacks" do
      foo = false
      bar = false
      subject.add("foo") { foo = true }
      subject.add("bar") { bar = true }

      subject.write("test")

      expect(foo).to eq(true)
      expect(bar).to eq(true)
    end

    it "saves the data to an YAML file" do
      # unmock the File.write call
      allow(File).to receive(:write).and_call_original

      # write to a tempfile
      tmpfile = Tempfile.new
      begin
        subject.write("test", nil, tmpfile)

        # check the file is not empty
        expect(File.stat(tmpfile).size).to be > 0

        # it can be parsed without errors
        data = nil
        expect { data = YAML.load_file(tmpfile) }.to_not raise_error

        # expected data structure
        expect(data).to be_a Hash
      ensure
        tmpfile.unlink
      end
    end
  end
end

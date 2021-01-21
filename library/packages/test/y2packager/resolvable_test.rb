#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/resolvable"
require "tmpdir"

Yast.import "Arch"

# signature callback for accepting unsigned files
class SignatureCheck
  include Yast::Logger

  def accept_unsigned_file(file, _repo)
    log.info "Accepting unsigned file #{file.inspect}"
    true
  end
end

signature_checker = SignatureCheck.new

# This is rather an integration test because it actually
# reads a real repository metadata using libzypp.
describe Y2Packager::Resolvable do
  before(:all) do
    # avoid writing to the protected /var/cache/zypp path
    @tmpdir = Dir.mktmpdir
    Yast::Pkg.TargetInitialize(@tmpdir)

    # the testing repositories are not signed, temporarily allow using unsigned files
    Yast::Pkg.CallbackAcceptUnsignedFile(
      Yast::fun_ref(
        signature_checker.method(:accept_unsigned_file),
        "boolean (string, integer)"
      )
    )

    # add the repository
    test_repo = File.join(__dir__, "/zypp/test_repo")
    Yast::Pkg.SourceCreate("dir:#{test_repo}", "/")

    # add the repository
    test_repo = File.join(__dir__, "/zypp/sle15-sp2-updates")
    Yast::Pkg.SourceCreate("dir:#{test_repo}", "/")

    # restore the default callback
    Yast::Pkg.CallbackAcceptUnsignedFile(nil)
  end

  after(:all) do
    # close the package manager
    Yast::Pkg.SourceFinishAll
    Yast::Pkg.TargetFinish

    # remove the tmpdir
    FileUtils.remove_entry(@tmpdir)
  end

  describe ".find" do
    it "finds packages" do
      res = Y2Packager::Resolvable.find(kind: :package)
      expect(res).to_not be_empty
      expect(res.all? { |r| r.kind == :package }).to be true
    end

    it "finds packages with a name" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.find(kind: :package, name: "yast2-add-on")
      expect(res).to_not be_empty
      expect(res.all? { |r| r.kind == :package && r.name == "yast2-add-on" }).to be true
    end

    it "finds multiple instances of the same product" do
      res = Y2Packager::Resolvable.find(kind: :product, name: "SLES")
      # two SLES products
      expect(res.size).to eq(2)
      # in the same version "15.2-0"
      res.each do |r|
        expect(r.name) == "SLES"
        expect(r.version) == "15.2-0"
      end
    end

    it "can distinguish between the same instances" do
      # each product refers to a different release RPM package
      paths = Y2Packager::Resolvable.find(kind: :product, name: "SLES").map(&:path)
      expect(paths).to include("./noarch/sles-release-15.2-49.1.noarch.rpm")
      expect(paths).to include("./noarch/sles-release-15.2-52.1.noarch.rpm")
    end
  end

  describe ".any?" do
    it "returns true if a package is found" do
      expect(Y2Packager::Resolvable.any?(kind: :package)).to be true
    end

    it "returns true if a package with name is found" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      expect(Y2Packager::Resolvable.any?(kind: :package, name: "yast2-add-on")).to be true
    end

    it "returns false if a package is not found" do
      expect(Y2Packager::Resolvable.any?(kind: :package, name: "not existing")).to be false
    end

    it "returns false if a product is not found" do
      expect(Y2Packager::Resolvable.any?(kind: :product, name: "openSUSE")).to be false
    end
  end

  describe "#vendor" do
    it "lazy loads the missing attributes" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.find(kind: :package, name: "yast2-add-on").first
      expect(Yast::Pkg).to receive(:Resolvables).with(anything, [:vendor]).and_call_original
      expect(res.vendor).to eq("obs://build.opensuse.org/YaST")
    end

    it "does not load the preloaded attributes again" do
      res = Y2Packager::Resolvable.find({ kind: :package, name: "yast2-add-on" }, [:vendor]).first
      expect(Yast::Pkg).to_not receive(:Resolvables).with(anything, [:vendor])
      expect(res.vendor).to eq("obs://build.opensuse.org/YaST")
    end

    it "raises an exception if the resolvable cannot be uniquely identified for lazy loading" do
      # this a bit artificial situation, create a Resolvable from an incomplete hash
      # (missing version and other attributes)
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.new(kind: :package, name: "yast2-add-on")
      expect { res.vendor }.to raise_error(RuntimeError, /missing attributes/i)
    end
  end

  describe "#method_missing" do
    it "raises NoMethodError when the attribute does not exist" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.find(kind: :package, name: "yast2-add-on").first
      expect { res.not_existing_method(:foo) }.to raise_error(NoMethodError)
    end

    it "raises ArgumentError when an argument is passed to a preloaded attribute" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.find(kind: :package, name: "yast2-add-on").first
      expect { res.name("dummy") }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError when an argument is passed to a lazy loaded method" do
      # use some noarch package here, the testing data covers only the x86_64 arch
      res = Y2Packager::Resolvable.find(kind: :package, name: "yast2-add-on").first
      expect { res.vendor("dummy") }.to raise_error(ArgumentError)
    end
  end
end

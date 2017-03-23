#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "WorkflowManager"

describe Yast::WorkflowManager do
  subject { Yast::WorkflowManager }

  describe "#ReplaceWorkflowModule" do
    let(:workflow) do
      {
        "defaults" => { "archs" => "all" },
        "stage"    => "continue",
        "mode"     => "autoinstallation",
        "modules"  => [
          { "label" => "Perform Installation", "name" => "autopost" },
          { "label" => "System Configuration", "name" => "autoconfigure" }
        ]
      }
    end
    let(:old) { "autoconfigure" }
    let(:new) { { "label" => "Custom Module", "name" => "custom" } }
    let(:domain) { "some-domain" }
    let(:keep) { true }

    context "when keep is set to true" do
      it "inserts the new modules before the old one" do
        replaced = subject.ReplaceWorkflowModule(workflow, old, [new], domain, keep)
        expect(replaced["modules"]).to include(new.merge("textdomain" => domain))

        modules = replaced["modules"].map { |m| m["name"] }
        expect(modules).to eq(["autopost", "custom", "autoconfigure"])
      end
    end

    context "when keep is set to false" do
      let(:keep) { false }
      it "replaces the old one with the new modules" do
        replaced = subject.ReplaceWorkflowModule(workflow, old, [new], domain, keep)
        expect(replaced["modules"]).to include(new.merge("textdomain" => domain))

        modules = replaced["modules"].map { |m| m["name"] }
        expect(modules).to eq(["autopost", "custom"])
      end
    end

    context "when the old module is not found" do
      let(:old) { "proposal" }

      it "does not modify the workflow and logs the error" do
        expect(subject.log).to receive(:warn).with(/workflow module 'proposal' not found/)
        replaced = subject.ReplaceWorkflowModule(workflow, old, [new], domain, keep)
        expect(replaced).to eq(workflow)
      end
    end
  end

  describe "#IntegrateWorkflow" do
    let(:installation_updated) { true }
    let(:product_info_updated) { true }
    let(:new_proposals_added) { true }
    let(:workflows_replaced) { true }
    let(:inst_finish_updated) { true }
    let(:filename) { "installation.xml" }

    let(:proposal) do
      { "name" => "testing", "mode" => "installation", "proposal_modules" => ["prop1"] }
    end

    let(:workflow) do
      { "mode" => "installation", "modules" => ["mod1"] }
    end

    let(:control) do
      {
        "display_name" => "new workflow",
        "proposals"    => [proposal],
        "workflows"    => [workflow],
        "textdomain"   => "control",
        "update"       => {
          "inst_finish" => { "before_chroot" => ["before_chroot_1"] }
        }
      }
    end

    before do
      allow(Yast::XML).to receive(:XMLToYCPFile).with(filename).and_return(control)
      allow(subject).to receive(:UpdateInstallation).and_return(installation_updated)
      allow(subject).to receive(:UpdateProductInfo).and_return(product_info_updated)
      allow(subject).to receive(:AddNewProposals).and_return(new_proposals_added)
      allow(subject).to receive(:Replaceworkflows).and_return(workflows_replaced)
      allow(subject).to receive(:UpdateInstFinish).and_return(inst_finish_updated)
    end

    it "updates the installation" do
      expect(subject).to receive(:UpdateInstallation)
        .with(control["update"], "new workflow", "control").and_return(true)
      expect(subject.IntegrateWorkflow(filename)).to eq(true)
    end

    it "updates the product info" do
      expect(subject).to receive(:UpdateProductInfo)
        .with(control, filename).and_return(true)
      expect(subject.IntegrateWorkflow(filename)).to eq(true)
    end

    it "adds new proposals" do
      expect(subject).to receive(:AddNewProposals)
        .with(control["proposals"]).and_return(true)
      expect(subject.IntegrateWorkflow(filename)).to eq(true)
    end

    it "adds inst_finish steps" do
      expect(subject).to receive(:UpdateInstFinish)
        .with(control["update"]["inst_finish"])
      expect(subject.IntegrateWorkflow(filename)).to eq(true)
    end

    context "when fails to update the installation" do
      let(:installation_updated) { false }

      it "logs the error and returns false" do
        expect(Yast::Builtins).to receive(:y2error)
          .with(/to update installation/)
        expect(subject.IntegrateWorkflow(filename)).to eq(false)
      end
    end

    context "when fails to update the product info" do
      let(:product_info_updated) { false }

      it "logs the error and returns false" do
        expect(Yast::Builtins).to receive(:y2error)
          .with(/to set product options/)
        expect(subject.IntegrateWorkflow(filename)).to eq(false)
      end
    end

    context "when fails to add new proposals" do
      let(:new_proposals_added) { false }

      it "logs the error and returns false" do
        expect(Yast::Builtins).to receive(:y2error)
          .with(/to add new proposals/)
        expect(subject.IntegrateWorkflow(filename)).to eq(false)
      end
    end

    context "when fails to replace workflows" do
      let(:workflows_replaced) { false }

      it "logs the error and returns false" do
        expect(Yast::Builtins).to receive(:y2error)
          .with(/to replace workflows/)
        expect(subject.IntegrateWorkflow(filename)).to eq(false)
      end
    end

    context "when fails to update inst_finish" do
      let(:inst_finish_updated) { false }

      it "logs the error and returns false" do
        expect(Yast::Builtins).to receive(:y2error)
          .with(/inst_finish steps failed/)
        expect(subject.IntegrateWorkflow(filename)).to eq(false)
      end
    end
  end

  describe "#UpdateInstallation" do
    let(:workflow) do
      { "mode"     => "installation",
        "archs"    => "",
        "stage"    => "",
        "defaults" => { "archs" => "" } }
    end
    let(:proposal) { { "mode" => "installation", "archs" => "", "stage" => "" } }

    let(:update) do
      {
        "system_roles" => { "insert_system_roles" => [] },
        "workflows"    => [workflow],
        "proposals"    => [proposal]
      }
    end

    let(:name) { "addon name" }
    let(:domain) { "control" }

    it "updates proposals" do
      expect(subject).to receive(:UpdateProposals).with(update["proposals"], name, domain)
      subject.UpdateInstallation(update, name, domain)
    end

    it "updates workflows" do
      expect(subject).to receive(:UpdateWorkflows).with(update["workflows"], name, domain)
      subject.UpdateInstallation(update, name, domain)
    end

    it "updates system roles" do
      expect(subject).to receive(:update_system_roles).with(update["system_roles"])
      subject.UpdateInstallation(update, name, domain)
    end
  end

  describe "#update_system_roles" do
    let(:system_roles) do
      {
        "insert_system_roles" => [
          {
            "position"     => -1,
            "system_roles" => [additional_role]
          }
        ]
      }
    end

    let(:additional_role) { { "id" => "additional_role" } }
    let(:default_role) { { "id" => "default_role" } }

    before do
      Yast::ProductControl.system_roles = [default_role]
    end

    it "add system roles at the beginning" do
      subject.update_system_roles(system_roles)
      expect(Yast::ProductControl.system_roles).to eq([default_role, additional_role])
    end
  end

  describe "#DumpCurrentSettings" do
    let(:settings) do
      {
        workflows:     ["workflow_1"],
        proposals:     ["proposal_1"],
        system_roles:  ["system_role_1"],
        clone_modules: ["lan"],
        inst_finish:   { "before_chroot" => ["before_chroot_1"] }
      }
    end

    before do
      settings.each do |key, value|
        allow(Yast::ProductControl).to receive(key).and_return(value)
      end
    end

    it "returns workflows" do
      expect(subject.DumpCurrentSettings["workflows"]).to eq(settings[:workflows])
    end

    it "returns proposals" do
      expect(subject.DumpCurrentSettings["proposals"]).to eq(settings[:proposals])
    end

    it "returns inst_finish" do
      expect(subject.DumpCurrentSettings["inst_finish"]).to eq(settings[:inst_finish])
    end

    it "returns system_roles" do
      expect(subject.DumpCurrentSettings["system_roles"]).to eq(settings[:system_roles])
    end

    it "returns unmerged_changes" do
      expect(subject.DumpCurrentSettings["unmerged_changes"]).to eq(false)
    end
  end

  describe "#GetControlFileFromPackage" do
    let(:repo_id) { 42 }
    let(:product_package) { "foo-release" }
    let(:product) { { "name" => "foo", "source" => repo_id, "product_package" => product_package } }
    let(:ext_package) { "foo-installation" }
    let(:extension) { { "name" => ext_package, "source" => repo_id } }
    let(:release) do
      { "name" => product_package, "source" => repo_id,
      "deps" => ["provides" => "installerextension(#{ext_package})"] }
    end

    before do
      # generic mocks, can be are overriden in the tests
      allow(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([product])
      allow(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([release])
      allow(Yast::Pkg).to receive(:ResolvableProperties).with(ext_package, :package, "").and_return([extension])
      allow_any_instance_of(Packages::PackageDownloader).to receive(:download)
      allow_any_instance_of(Packages::PackageExtractor).to receive(:extract)
      # allow using it at other places
      allow(File).to receive(:exist?).and_call_original
    end

    it "returns nil if the repository does not provide any product" do
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the product does not refer to a release package" do
      product = { "name" => "foo", "source" => repo_id }
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([product])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the product belongs to a different repository" do
      product = { "name" => "foo", "source" => repo_id + 1 }
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([product])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the release package cannot be found" do
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the release package does not have any dependencies" do
      release = { "name" => "foo", "source" => repo_id }
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([release])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the release package does not have any installerextension() provides" do
      release = { "name" => "foo", "source" => repo_id, "deps" => ["provides" => "foo"] }
      expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([release])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns nil if the installer extension package is not found" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with(ext_package, :package, "").and_return([])
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "downloads and extracts the extension package" do
      expect_any_instance_of(Packages::PackageDownloader).to receive(:download)
      expect_any_instance_of(Packages::PackageExtractor).to receive(:extract)
      allow(File).to receive(:exist?)
      subject.GetControlFileFromPackage(repo_id)
    end

    it "returns nil if the extracted package does not contain installation.xml" do
      expect(File).to receive(:exist?).with(/installation\.xml\z/).and_return(false)
      expect(subject.GetControlFileFromPackage(repo_id)).to be nil
    end

    it "returns the installation.xml path if the extracted package contains it" do
      expect(File).to receive(:exist?).with(/installation.xml\z/).and_return(true)
      # the returned path contains "/installation.xml" at the end
      expect(subject.GetControlFileFromPackage(repo_id)).to end_with("/installation.xml")
    end
  end
end

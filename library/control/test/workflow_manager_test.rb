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

    let(:additional_role) do
      { "id" => "additional_role" }
    end

    let(:control) do
      {
        "display_name" => "new workflow",
        "proposals"    => [proposal],
        "workflows"    => [workflow],
        "textdomain"   => "control",
        "system_roles" => [additional_role],
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
      Yast::ProductControl.system_roles = []
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

    it "adds roles" do
      expect(subject.IntegrateWorkflow(filename)).to eq(true)
      expect(Yast::ProductControl.system_roles).to eq([additional_role])
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
end

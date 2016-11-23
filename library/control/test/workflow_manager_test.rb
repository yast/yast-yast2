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
end

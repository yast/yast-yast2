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
      { "mode"           => "installation",
        "archs"          => "",
        "stage"          => "continue",
        "append_modules" => [{ "label" => "Perform Update", "name" => "autopost" },
                             { "execute" => "inst_rpmcopy_secondstage",
                               "label"   => "Perform Update",
                               "name"    => "rpmcopy_secondstage_autoupgrade" },
                             { "heading" => "yes", "label" => "Configuration" },
                             { "label" => "System Configuration", "name" => "autoconfigure" }],
        "defaults"       => { "archs"       => "",
                              "enable_back" => "no",
                              "enable_next" => "no" } }
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

    it "generate new workflows with append_modules" do
      Yast::ProductControl.workflows = []
      subject.UpdateWorkflows(update["workflows"], name, domain)
      expect(Yast::ProductControl.workflows.first["modules"].size).to eq(workflow["append_modules"].size)
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

  describe "#control_file" do
    # setup fake products and their packages
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

    context "when repository id is passed" do
      it "returns nil if the repository does not provide any product" do
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([])
        expect(subject.control_file(repo_id)).to be nil
      end

      it "returns nil if the product does not refer to a release package" do
        product = { "name" => "foo", "source" => repo_id }
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([product])
        expect(subject.control_file(repo_id)).to be nil
      end

      it "returns nil if the product belongs to a different repository" do
        product = { "name" => "foo", "source" => repo_id + 1 }
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with("", :product, "").and_return([product])
        expect(subject.control_file(repo_id)).to be nil
      end

      it "returns nil if the release package cannot be found" do
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([])
        expect(subject.control_file(repo_id)).to be nil
      end

      it "returns nil if the release package does not have any dependencies" do
        release = { "name" => "foo", "source" => repo_id }
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([release])
        expect(subject.control_file(repo_id)).to be nil
      end

      it "returns nil if the release package does not have any installerextension() provides" do
        release = { "name" => "foo", "source" => repo_id, "deps" => ["provides" => "foo"] }
        expect(Yast::Pkg).to receive(:ResolvableDependencies).with(product_package, :package, "").and_return([release])
        expect(subject.control_file(repo_id)).to be nil
      end
    end

    it "returns nil if the installer extension package is not found" do
      expect(Yast::Pkg).to receive(:ResolvableProperties).with(ext_package, :package, "").and_return([])
      expect(subject.control_file(repo_id)).to be nil
    end

    context "downloading the installer extension package fails" do
      before do
        expect_any_instance_of(Packages::PackageDownloader).to receive(:download).and_raise(Packages::PackageDownloader::FetchError)
        allow(Yast::Report).to receive(:Error)
      end

      it "reports an error" do
        expect(Yast::Report).to receive(:Error)
        subject.control_file(repo_id)
      end

      it "returns nil" do
        expect(subject.control_file(repo_id)).to be nil
      end
    end

    context "extracting the installer extension package fails" do
      before do
        expect_any_instance_of(Packages::PackageExtractor).to receive(:extract).and_raise(Packages::PackageExtractor::ExtractionFailed)
        allow(Yast::Report).to receive(:Error)
      end

      it "reports an error" do
        expect(Yast::Report).to receive(:Error)
        subject.control_file(repo_id)
      end

      it "returns nil" do
        expect(subject.control_file(repo_id)).to be nil
      end
    end

    it "downloads and extracts the extension package" do
      expect_any_instance_of(Packages::PackageDownloader).to receive(:download).with(instance_of(String))
      expect(Packages::PackageExtractor).to receive(:new).with(instance_of(String)).and_call_original
      expect_any_instance_of(Packages::PackageExtractor).to receive(:extract).with(instance_of(String))
      allow(File).to receive(:exist?)
      subject.control_file(repo_id)
    end

    context "if downloading and extracting worked" do
      before do
        allow(Dir).to receive(:glob).with(/installation-products/).and_return product_files
        allow(Dir).to receive(:glob).with(/system-roles/).and_return role_files

        allow(File).to receive(:exist?) do |name|
          product_files.include?(name) || role_files.include?(name)
        end

        allow(File).to receive(:exist?).with(/installation\.xml\z/).and_return installation_xml
      end

      context "and the package contains a control file in the installation-products dir" do
        let(:product_files) { ["/tmp/usr/share/installation-products/big_deal.xml"] }

        context "and contains no control file in other locations" do
          let(:role_files) { [] }
          let(:installation_xml) { false }

          it "returns the path of the installation-products control file" do
            expect(subject.control_file(repo_id))
              .to eq "/tmp/usr/share/installation-products/big_deal.xml"
          end
        end

        context "and also contains files in the system-roles dir" do
          let(:role_files) { ["/tmp/usr/share/system-roles/superyast.xml"] }
          let(:installation_xml) { false }

          it "returns the path of the installation-products control file" do
            expect(subject.control_file(repo_id))
              .to eq "/tmp/usr/share/installation-products/big_deal.xml"
          end
        end

        context "and also contains /installation.xml" do
          let(:role_files) { [] }
          let(:installation_xml) { true }

          it "returns the path of the installation-products control file" do
            expect(subject.control_file(repo_id))
              .to eq "/tmp/usr/share/installation-products/big_deal.xml"
          end
        end
      end

      context "and the package contains several control files in the installation-products dir" do
        let(:product_files) do
          [
            "/tmp/usr/share/installation-products/big_deal.xml",
            "/tmp/usr/share/installation-products/smaller_deal.xml"
          ]
        end
        let(:role_files) { [] }
        let(:installation_xml) { true }

        it "returns the path of one of the installation-products control files" do
          expect(product_files).to include(subject.control_file(repo_id))
        end
      end

      context "and the package contains no control file in the installation-products dir" do
        let(:product_files) { [] }

        context "and it contains a control file in the system-roles dir" do
          let(:role_files) { ["/tmp/usr/share/system-roles/superyast.xml"] }

          context "and also contains /installation.xml" do
            let(:installation_xml) { true }

            it "returns the path of the system-roles control file" do
              expect(subject.control_file(repo_id)).to eq "/tmp/usr/share/system-roles/superyast.xml"
            end
          end

          context "and contains no /installation.xml" do
            let(:installation_xml) { false }

            it "returns the path of the system-roles control file" do
              expect(subject.control_file(repo_id)).to eq "/tmp/usr/share/system-roles/superyast.xml"
            end
          end
        end

        context "and it contains several control files in the system-roles dir" do
          let(:role_files) do
            ["/tmp/usr/share/system-roles/role1.xml", "/tmp/usr/share/system-roles/role2.xml"]
          end
          let(:installation_xml) { true }

          it "returns the path of one of the system-roles control files" do
            expect(role_files).to include(subject.control_file(repo_id))
          end
        end

        context "and it contains no control file in the system-roles dir either" do
          let(:role_files) { [] }

          context "but it contains an installation.xml control file" do
            let(:installation_xml) { true }

            it "returns the path of the control file" do
              # the returned path contains "/installation.xml" at the end
              expect(subject.control_file(repo_id)).to end_with("/installation.xml")
            end
          end

          context "and it contains no /installation.xml" do
            let(:installation_xml) { false }

            it "returns nil" do
              expect(subject.control_file(repo_id)).to be nil
            end
          end
        end
      end
    end
  end

  describe "#addon_control_dir" do
    let(:src_id) { 3 }

    after do
      # remove the created directory after each run to ensure the same initial state
      FileUtils.remove_entry(subject.addon_control_dir(src_id))
    end

    it "returns a directory path" do
      expect(File.directory?(subject.addon_control_dir(src_id))).to be true
    end

    context "a file already exists in the target directory" do
      let(:path) { subject.addon_control_dir(src_id) + "/test" }

      before do
        # write some dummy file first
        File.write(path, "")
      end

      it "removes the existing content if cleanup is requested" do
        expect { subject.addon_control_dir(src_id, cleanup: true) }.to change { File.exist?(path) }.from(true).to(false)
      end

      it "keeps the existing content if cleanup is not requested" do
        expect { subject.addon_control_dir(src_id) }.to_not(change { File.exist?(path) })
      end
    end

    it "does not create the directory if it already exists" do
      dir = subject.addon_control_dir(src_id)
      expect(File.directory?(subject.addon_control_dir(src_id))).to be true
      expect(FileUtils).to_not receive(:mkdir_p).with(dir)
      subject.addon_control_dir(src_id)
    end
  end

  describe "#merge_product_workflow" do
    let(:product) do
      instance_double("Y2Packager::Product", label: "SLES", installation_package: "package",
        installation_package_repo: 42)
    end

    before do
      subject.main
      allow(subject).to receive(:AddWorkflow)
      allow(subject).to receive(:MergeWorkflows)
      allow(subject).to receive(:RedrawWizardSteps)
    end

    it "merges installation package workflow" do
      expect(subject).to receive(:AddWorkflow).with(:package, product.installation_package_repo, "package")
      subject.merge_product_workflow(product)
    end

    context "when other product's workflow was previously merged" do
      before do
        subject.merge_product_workflow(product)
      end

      it "removes the previous workflow" do
        expect(subject).to receive(:RemoveWorkflow).with(:package, product.installation_package_repo, "package")
        subject.merge_product_workflow(product)
      end
    end
  end

  describe "#merge_modules_extensions" do
    let(:packages) { ["package_a", "package_b"] }

    before do
      subject.main
      allow(subject).to receive(:AddWorkflow)
      allow(subject).to receive(:MergeWorkflows)
      allow(subject).to receive(:RedrawWizardSteps)
    end

    it "merges module extension package workflow" do
      expect(subject).to receive(:AddWorkflow).with(:package, 0, "package_a")
      expect(subject).to receive(:AddWorkflow).with(:package, 0, "package_b")
      subject.merge_modules_extensions(packages)
    end

    context "when running method again it" do
      before do
        subject.merge_modules_extensions(["package_c", "package_a"])
      end

      it "removes the previous packages workflow" do
        expect(subject).to receive(:RemoveWorkflow).with(:package, 0, "package_c")
        expect(subject).to receive(:RemoveWorkflow).with(:package, 0, "package_a")
        subject.merge_modules_extensions(packages)
      end
    end
  end

end

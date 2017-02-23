#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "MailAliases"

describe Yast::MailAliases do
  subject { described_class }

  around do |example|
    chroot_path = File.expand_path("../data/", __FILE__)
    change_scr_root(chroot_path) do
      subject.ReadAliases
      example.call
    end
  end

  describe ".ReadAliases" do
    it "reads aliases table and sets it without root alias" do
      expected_output =[{"comment"=>"",
        "alias"=>"postmaster",
        "destinations"=>"root"},
        {"comment"=>"", "alias"=>"mailer-daemon", "destinations"=>"postmaster"},
        {"comment"=>"", "alias"=>"virusalert", "destinations"=>"root"},
        {"comment"=>"",
        "alias"=>"administrator",
        "destinations"=>"root"}]

      subject.ReadAliases
      expect(subject.aliases).to eq expected_output
    end

    it "reads root alias" do
      subject.ReadAliases
      expect(subject.root_alias).to eq "jreidinger"
    end
  end

  describe ".MergeRootAlias" do
    it "prepends new root_alias to copy of argument with its original comment" do
      input = [
        {"comment"=>"", "alias"=>"mailer-daemon", "destinations"=>"postmaster"}
      ]
      subject.root_alias = "my_little_pony"

      expected_output = [
        {"comment"=>"", "alias"=>"root", "destinations" => "my_little_pony"},
        {"comment"=>"", "alias"=>"mailer-daemon", "destinations"=>"postmaster"}
      ]


      expect(subject.MergeRootAlias(input)).to eq expected_output
    end
  end

  describe ".GetRootAlias" do
    it "reads alieases and return root one" do
      expect(subject.GetRootAlias).to eq "jreidinger"
    end
  end
end

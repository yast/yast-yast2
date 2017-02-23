#! /usr/bin/env rspec

require_relative "test_helper"

require "cfa/aliases"
require "cfa/memory_file"

describe CFA::Aliases do
  let(:file) do
    chroot_path = File.expand_path("../data/etc/aliases", __FILE__)
    content = File.read(chroot_path)
    CFA::MemoryFile.new(content)
  end

  subject { described_class.new(file_handler: file) }

  describe "#aliases" do
    it "returns hash aliases mapped to its destination" do
      expected_output = {
        "administrator" => "root",
        "mailer-daemon" => "postmaster",
        "postmaster" => "root",
        "root" => "jreidinger",
        "virusalert" => "root, test"
      }
      subject.load
      expect(subject.aliases).to eq(expected_output)
    end
  end

  describe "#aliases=" do
    it "merges new values and try to place it when old one was" do
      new_aliases = {
        "administrator" => "root",
        "mailer-daemon" => "postmaster",
        "root" => "jreidinger, test",
        "virusalert" => "root",
        "new_user" => "old_user"
      }

      subject.load
      subject.aliases = new_aliases

      subject.save

      expected_file_content = <<-EOF
# This is the aliases file - it says who gets mail for whom.
# >>>>>>>>>>      The program "newaliases" will need to be run
# >> NOTE >>      after this file is updated for any changes
# >>>>>>>>>>      to show through to sendmail.
# It is probably best to not work as user root and redirect all
# email to "root" to the address of a HUMAN who deals with this
# system's problems. Then you don't have to check for important
# email too often on the root account.
# The "\\root" will make sure that email is also delivered to the
# root-account, but also forwared to the user "joe".
#root:\t\tjoe, \\root
root:\tjreidinger, test
# Basic system aliases that MUST be present.
mailer-daemon:\tpostmaster
# amavis
virusalert:\troot
# General redirections for pseudo accounts in /etc/passwd.
administrator:\troot
# mlmmj needs only one alias to function; this is with a mailinglist in
# /var/spool/mlmmj/myownlist (remember full path):
new_user:\told_user
EOF
      expect(file.content).to eq expected_file_content
    end
  end
end



# encoding: utf-8

module Yast
  class GetSetServiceStatusClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "target" => { "tmpdir" => "/tmp", "stat" => { "isreg" => true } },
        "init"   => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => {
              "iscsid"            => {
                "start" => ["3", "5"],
                "stop"  => ["3", "5"]
              },
              "boot.iscsid-early" => { "start" => ["B"], "stop" => [] }
            },
            "comment"  => {
              "iscsid"            => {
                "defstart"         => ["3", "5"],
                "defstop"          => [],
                "description"      => "",
                "provides"         => ["iscsi"],
                "reqstart"         => ["$network"],
                "reqstop"          => [],
                "shortdescription" => "Starts and stops the iSCSI client initiator",
                "shouldstart"      => [],
                "shouldstop"       => []
              },
              "boot.iscsid-early" => {
                "defstart"         => ["B"],
                "defstop"          => [],
                "description"      => "",
                "provides"         => ["iscsiboot"],
                "reqstart"         => ["boot.proc"],
                "reqstop"          => [],
                "shortdescription" => "Starts the iSCSI initiator daemon",
                "shouldstart"      => [],
                "shouldstop"       => []
              }
            }
          }
        }
      }
      TESTSUITE_INIT([@READ, {}, {}], nil)

      Yast.import "Service"


      TEST(lambda { Service.Enabled("iscsid") }, [@READ, {}, {}], nil)
      TEST(lambda { Service.Enable("boot.iscsid-early") }, [@READ, {}, {}], nil)
      TEST(lambda { Service.Enable("iscsid") }, [@READ, {}, {}], nil)

      nil
    end
  end
end

Yast::GetSetServiceStatusClient.new.main

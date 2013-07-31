# encoding: utf-8

# File:	XXXXXX
# Package:	yast2
# Summary:	XXXXXX
# Author:	Stanislav Visnovsky <visnov@suse.cz>
#
# $Id$
module Yast
  module TestsuitedataInclude
    def initialize_testsuitedata(include_target)
      Yast.import "CommandLine"

      @cmdline = {
        "help"       => "Configuration of network cards",
        "id"         => "lan",
        "initialize" => fun_ref(method(:init), "void ()"),
        "finish"     => fun_ref(method(:finish), "void ()"),
        "guihandler" => fun_ref(method(:GUI), "void ()"),
        "actions"    => {
          "list"   => {
            "help"    => "display configuration summary",
            "example" => "lan list configured",
            "options" => ["non_strict"]
          },
          "add"    => { "help" => "add a network card" },
          "delete" => { "help" => "delete a network card" }
        },
        "options"    => {
          "propose"      => {
            "help"    => "propose a configuration",
            "example" => "lan add propose",
            "type"    => ""
          },
          "configured"   => {
            "help" => "list only configured cards",
            "type" => ""
          },
          "unconfigured" => {
            "help" => "list only not configured cards",
            "type" => ""
          },
          "device"       => {
            "help"    => "device ID",
            "type"    => "string",
            "example" => "lan add device=eth0"
          },
          "ip"           => { "help" => "device address", "type" => "ip" },
          "netmask"      => { "help" => "network mask", "type" => "netmask" },
          "blem"         => {
            "help"     => "other argument (without spaces and '1')",
            "type"     => "regex",
            "typespec" => "^[^ 1]+$"
          },
          "atboot"       => {
            "help"     => "turning on the device at boot",
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          }
        },
        "mappings"   => {
          "list"   => ["configured", "unconfigured"],
          "add"    => ["device", "ip", "netmask", "blem", "atboot"],
          "delete" => ["device"]
        }
      }
    end

    def init
      CommandLine.Print("Initialization")

      nil
    end

    def finish
      CommandLine.Print("Finish")

      nil
    end

    def GUI
      CommandLine.Print("GUI")

      nil
    end
  end
end

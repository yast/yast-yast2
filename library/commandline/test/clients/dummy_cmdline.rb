module Yast
  class DummyCmdlineClient < Client
    def main
      Yast.import "CommandLine"

      # Command line definition
      cmdline = {
        # Commandline help title
        "help"       => "Dummy test client",
        "id"         => "dummy",
        "initialize" => fun_ref(method(:init), "boolean ()"),
        "finish"     => proc { puts "Finish called" },
        "actions"    => {
          "echo"  => {
            # Commandline command help
            "help"    => _(
              "Prints the passed argument"
            ),
            "example" => "dummy echo text=something",
            "handler" => fun_ref(
              method(:echo_handler),
              "boolean (map <string, string>)"
            )
          },
          "crash" => {
            # Commandline command help
            "help"    => _(
              "Raises an exception"
            ),
            "example" => "dummy crash",
            "handler" => fun_ref(
              method(:crash_handler),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "text" => {
            # Commandline option help
            "help" => "Any text",
            "type" => "string"
          }
        },
        "mappings"   => {
          "echo" => ["text"]
        }
      }

      CommandLine.Run(cmdline)
    end

    def init
      puts "Initialize called"
      true
    end

    def echo_handler(options)
      puts options["text"]
      true
    end

    def crash_handler(_options)
      raise "I crashed"
    end
  end
end

Yast::DummyCmdlineClient.new.main

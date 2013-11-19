require 'pathname'
require 'ostruct'

module Yast
  class HooksClass < Module
    attr_reader :hooks, :last

    def initialize
      textdomain 'base'
      @hooks = {}
    end

    def run hook_name
      hook = register(hook_name, caller.first)
      hook.execute
      @last = hook
    end

    def find hook_name
      hooks[hook_name]
    end

    def all
      hooks
    end

    def exists? hook_name
      !!find(hook_name)
    end

    private

    def register hook_name, client_file
      if exists?(hook_name)
        raise "Hook '#{hook_name}' is already registered from #{find(hook_name).client_path}"
      end
      hooks[hook_name] = Hook.new(hook_name, client_file)
    end

    class Hook
      DIR = '/var/lib/YaST2/hooks'

      attr_reader :results, :files, :client_path

      def initialize name, client_caller
        @files = find_hook_files(name).map {|path| HookFile.new(path) }
        @client_path = client_caller
      end

      def execute
        files.each &:execute
      end

      def results
        files.map &:result
      end

      def succeeded?
        files.all? {|hook_file| hook_file.result && hook_file.result.exit.zero? }
      end

      def failed?
        !succeeded?
      end

      private

      def find_hook_files hook_name
        Pathname.new(DIR).children.select do |file|
          file.basename.fnmatch?("#{hook_name}_[0-9][0-9]_*")
        end.sort
      end
    end

    class HookFile
      attr_reader :path, :content, :result

      def initialize path
        @path = path
      end

      def execute
        @result = OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), path.to_s))
      end

      def content
        @content ||= ::File.read(path)
      end
    end

  end
  Hooks = HooksClass.new
end

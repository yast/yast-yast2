require 'pathname'

module Yast
  class HooksClass < Module
    HOOKS_DIR = '/var/lib/YaST2/hooks'
    # Example: /var/lib/YaST2/wagon/hooks/before_package_migration_00_postgresql_backup

    attr_reader :hooks

    def initialize
      textdomain 'base'
      @hooks = {}
    end

    def run hook_name
      register(hook_name, caller.first).execute
    end

    def find hook_name
      hooks[hook_name]
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
      # validate the hook filename format
      attr_reader :results, :files, :client_path

      def initialize name, client_caller
        @files = find_hook_files(name).map {|path| Hook::File.new(path) }
        @client_path = client_caller
      end

      def execute
        files.each {|hook_file| hook_file.execute }
      end

      private

      def find_hook_files hook_name
        Pathname.new(HOOKS_DIR).children.select do |file|
          file.basename.fnmatch?(hook_name.to_s)
        end.sort
      end

      class File
        attr_reader :path, :content
        attr_reader :step, :number, :name

        def initialize path
          @path = path
          # split the file name into the parts
          # step name (defined by the yast client)
          # number   (set by the user)
          # prefix [optional] or is this needed?
          # name of the hook (defined by user)
        end

        def execute
          SCR.Execute(path(".target.bash"), path_to_file)
        end

        def content
          @content ||= ::File.read(path)
        end
      end
    end

  end
  Hooks = HooksClass.new
end

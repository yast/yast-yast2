require 'pathname'

module Yast
  class HooksClass < Module
    HOOKS_DIR = '/var/lib/YaST2/hooks'
    # Example: /var/lib/YaST2/hooks/before_package_migration_00_postgresql_backup

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
          file.basename.fnmatch?("#{hook_name}_[0-9][0-9]_*")
        end.sort
      end

      class File
        attr_reader :path, :content, :result

        def initialize path
          @path = path
        end

        def execute
          @result = File::Result.new(SCR.Execute(Path.new(".target.bash_output"), path))
        end

        def content
          @content ||= ::File.read(path)
        end

        class Result
          attr_reader :exit_code, :stderr, :stdout

          def initialize params
            @exit_code = params['exit']
            @stderr    = params['stderr']
            @stdout    = params['stdout'].split
          end
        end
      end
    end

  end
  Hooks = HooksClass.new
end

require 'pathname'
require 'ostruct'

module Yast
  class HooksClass < Module

    attr_reader :hooks, :last, :load_path

    def initialize
      textdomain 'base'
      @hooks = {}
      @load_path = HooksPath.new
    end

    def run hook_name
      hook = create(hook_name, caller.first)
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

    def create hook_name, source_file
      if hooks[hook_name]
        Builtins.y2warning "Hook '#{hook_name}' has already been run from #{hooks[hook_name].caller_path}"
      else
        hooks[hook_name] = Hook.new(hook_name, source_file, load_path)
      end
    end

    class HooksPath
      DEFAULT_DIR = '/var/lib/YaST2/hooks'

      attr_reader :path

      def initialize
        @path = Pathname.new(DEFAULT_DIR)
      end

      def join new_path
        path = path.join(new_path)
      end
    end


    class Hook
      attr_reader :name, :results, :files, :caller_path, :load_path

      def initialize name, caller_path, load_path
        Builtins.y2milestone "Creating hook '#{name}' from '#{caller_path}'"
        @name = name
        @files = find_hook_files(name).map {|path| HookFile.new(path) }
        @caller_path = caller_path
        @load_path = load_path
      end

      def execute
        Builtins.y2milestone "Executing hook '#{name}'"
        files.each &:execute
      end

      def results
        files.map &:result
      end

      def succeeded?
        files.all? &:succeeded?
      end

      def failed?
        !succeeded?
      end

      private

      def find_hook_files hook_name
        Builtins.y2milestone "Searching for hook files in '#{load_path}'..."
        hook_files = Pathname.new(load_path).children.select do |file|
          file.basename.fnmatch?("#{hook_name}_[0-9][0-9]_*")
        end
        Builtins.y2milestone "Found #{hook_files.size} hook files: " +
          "#{hook_files.map {|f| f.basename.to_s}.join(', ')}"
        hook_files.sort
      end
    end

    class HookFile
      attr_reader :path, :content, :result

      def initialize path
        @path = path
      end

      def execute
        Builtins.y2milestone "Executing hook file '#{path}'"
        @result = OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), path.to_s))
      end

      def content
        @content ||= ::File.read(path)
      end

      def succeeded?
        result.exit.zero?
      end
    end

  end
  Hooks = HooksClass.new
end

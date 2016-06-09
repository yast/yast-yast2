require "pathname"
require "ostruct"
require "yast"

## Description
#
#  Main goal of hooks is to execute a third party code within the workflow of
#  installation, system update or some other process. Hook files must be executable
#  files written in bash, ruby or anything else available in inst-sys environment.
#
#  The module provides method #run which creates a hook and executes it instantly.
#
#  This includes following actions:
#  * adding the hook into the hooks collection - every hook is identified by unique
#    name which should be self-descriptive
#  * looking up the files matching the hook script pattern: hook_name_[0-9][0-9]_*
#  * executing the identified hook files
#  * storing the results returned by the scripts for further inspection later if needed;
#    this might be useful if some of the files has failed and we want to show it the user.
#
#  If a hook script returns non-zero result, the whole hook is considered as failed.
#  By default the hooks are searched for in /var/lib/YaST2/hooks directory. This path
#  can be modified globally for all hooks before they get called.
#
## Example
#
#  * using a hook within a yast client
#
#  module Yast
#    import 'Hooks'
#
#    class MyFavoriteClient < Client
#      def main
#        # this will change the search path to /var/lib/YaST2/hooks/personal
#        Hooks.search_path.join!('personal')
#        # and this will set a completely different path
#        Hooks.search_path.set "/root/hooks"
#        hook = Hooks.run 'before_showing_ui'
#        # Lot of beautiful and useful code follows here.
#        # If needed make use of:
#        #   * hook.failed?
#        #   * hook.succeeded?
#        #   * hook.name
#        #   * hook.results
#        #   * hook.files
#        #   * hook.search_path
#        #   * Hooks.last.failed?
#        #   * Hooks.last.succeeded?
#        #   * Hooks.last.name
#        #   * Hooks.last.search_path
#        #   * Hooks.last.results
#        #   * Hooks.last.files
#        Hooks.run 'after_showing_ui'
#        # reset the search path if needed
#        Hooks.search_path.reset
#      end
#    end
#  end

module Yast
  class HooksClass < Module
    include Yast::Logger

    attr_reader :hooks, :last, :search_path

    private :hooks

    def initialize
      textdomain "base"
      @hooks = {}
      @search_path = SearchPath.new
    end

    def run(hook_name)
      hook_name = hook_name.to_s
      raise "Hook name not specified" if hook_name.empty?

      hook = create(hook_name, caller.first)
      hook.execute
      @last = hook
    end

    def find(hook_name)
      hooks[hook_name]
    end

    def all
      hooks.values
    end

    def exists?(hook_name)
      !!find(hook_name)
    end

  private

    def create(hook_name, source_file)
      if hooks[hook_name]
        log.warn "Hook '#{hook_name}' has already been run from #{hooks[hook_name].caller_path}"
        hooks[hook_name]
      else
        hooks[hook_name] = Hook.new(hook_name, source_file, search_path)
      end
    end

    class SearchPath
      DEFAULT_DIR = "/var/lib/YaST2/hooks".freeze

      attr_reader :path

      def initialize
        set_default_path
      end

      def join!(new_path)
        @path = path.join(new_path)
      end

      def reset
        set_default_path
      end

      def set(new_path)
        @path = Pathname.new(new_path)
      end

      def children
        path.children
      end

      def to_s
        path.to_s
      end

      def verify!
        if path.exist?
          path
        else
          raise "Hook search path #{path} does not exists"
        end
      end

    private

      def set_default_path
        @path = Pathname.new(DEFAULT_DIR)
      end
    end

    class Hook
      include Yast::Logger

      attr_reader :name, :results, :files, :caller_path, :search_path

      def initialize(name, caller_path, search_path)
        log.debug "Creating hook '#{name}' from '#{self.caller_path}'"
        search_path.verify!
        @search_path = search_path
        @name = name
        @files = find_hook_files(name).map { |path| HookFile.new(path) }
        @caller_path = caller_path.split(":in").first
      end

      def execute
        Builtins.y2milestone "Executing hook '#{name}'"
        files.each(&:execute)
      end

      def used?
        !files.empty?
      end

      def results
        files.map(&:result)
      end

      def succeeded?
        files.all?(&:succeeded?)
      end

      def failed?
        !succeeded?
      end

    private

      def find_hook_files(hook_name)
        log.debug "Searching for hook files in '#{search_path}'..."
        hook_files = search_path.children.select do |file|
          file.basename.fnmatch?("#{hook_name}_[0-9][0-9]_*")
        end
        unless hook_files.empty?
          log.info "Found #{hook_files.size} hook files: " \
            "#{hook_files.map { |f| f.basename.to_s }.join(", ")}"
        end
        hook_files.sort
      end
    end

    class HookFile
      include Yast::Logger

      attr_reader :path, :content, :result

      def initialize(path)
        @path = path
      end

      def execute
        log.info "Executing hook file '#{path}'"
        @result = OpenStruct.new(SCR.Execute(Path.new(".target.bash_output"), path.to_s))
        if failed?
          log.error "Hook file '#{path.basename}' failed with stderr: #{result.stderr}"
        end
        result
      end

      def content
        @content ||= ::File.read(path)
      end

      def output
        return "" unless result
        output = []
        output << "STDERR: #{result.stderr.strip}" unless result.stderr.empty?
        output << "STDOUT: #{result.stdout.strip}" unless result.stdout.empty?
        output.join("; ")
      end

      def succeeded?
        result.exit.zero?
      end

      def failed?
        !succeeded?
      end
    end
  end
  Hooks = HooksClass.new
end

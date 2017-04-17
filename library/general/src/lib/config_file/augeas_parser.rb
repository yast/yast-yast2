require "augeas"

module ConfigFile

  # Represent parsed augeas config tree with user friendly methods
  class AugeasTree
    def initialize
      @data = {}
    end

    def [](key)
      entry = @data.find{|d| d[:key] == key}
      return nil unless entry

      entry[:value]
    end

    def []=(key, value)
      entry = @data.find{|d| d[:key] == key}
      if entry
        entry[:value] = value
      else
        @data << {
          key:   key,
          value: value
        }
      end
    end

    def load_from_augeas(aug, prefix)
      matches = aug.match("#{prefix}/*")

      @data = matches.map do |aug_key|
        key = aug_key.sub(/^#{prefix}\//, "")
        key.sub!(/\[\d+\]/, "[]")
        {
          key:   key,
          value: aug.get(aug_key)
        }
      end
    end

    def save_to_augeas(aug, prefix)
      arrays = {}

      @data.each do |entry|
        key = entry[:key]
        if key.end_with?("[]")
          array_key = key.sub(/\[\]$/, "")
          arrays[array_key] ||= 0
          arrays[array_key] += 1
          key = array_key + "[#{arrays[array_key]}]"
        end
        aug.set("#{prefix}/#{key}", entry[:value])
      end
    end
  end

  # TODO: handle nested structures
  # @example read, print, modify and serialize again
  #    require "config_file/augeas_parser"
  #
  #    parser = ConfigFile::AugeasParser.new("sysconfig.lns")
  #    data = parser.parse(File.read("/etc/default/grub"))
  #
  #    puts data["GRUB_DISABLE_OS_PROBER"]
  #    data["GRUB_DISABLE_OS_PROBER"] = "true"
  #    puts parser.serialize(data)
  class AugeasParser
    def initialize(lens)
      @lens = lens
    end

    def parse(raw_string)
      @old_content = raw_string

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas::open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        if !aug.text_store(@lens, "/input", "/store")
          error = aug.error
          raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
        end

        tree = AugeasTree.new
        tree.load_from_augeas(aug, "/store")

        return tree
      end
    end

    def serialize(data)

      # open augeas without any autoloading and it should not touch disk and
      # load lenses as needed only
      root = load_path = nil
      Augeas::open(root, load_path, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", @old_content || "")
        data.save_to_augeas(aug, "/store")

        aug.text_retrieve(@lens, "/input", "/store", "/output")

        return aug.get("/output")
      end
    end
  end
end

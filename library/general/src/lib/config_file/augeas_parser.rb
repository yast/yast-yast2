require "augeas"

module ConfigFile
  # TODO: handle nested structures
  # TODO: use for data smarted structure that can search
  # @example read, print, modify and serialize again
  #
  #  parser = ConfigFile::AugeasParser.new("sysconfig.lns")
  #  data = parser.parse(File.read("/etc/default/grub"))
  #  puts data
  #  data.find { |d| d[:key] == "GRUB_DISABLE_OS_PROBER" }[:value] = "true"
  #  puts parser.serialize(data)
  class AugeasParser
    def initialize(lense)
      @lense = lense
    end

    def parse(raw_string)
      @old_content = raw_string

      Augeas::open(nil, nil, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", raw_string)
        if !aug.text_store(@lense, "/input", "/store")
          error = aug.error
          raise "Augeas error #{error[:message]}. Details: #{error[:details]}."
        end
        matches = aug.match("/store/*")

        return matches.map do |aug_key|
          key = aug_key.sub(/^\/store\//, "")
          key.sub!(/\[\d+\]/, "[]")
          {
            key:   key,
            value: aug.get(aug_key)
          }
        end
      end
    end

    def serialize(data)
      arrays = {}

      Augeas::open(nil, nil, Augeas::NO_MODL_AUTOLOAD) do |aug|
        aug.set("/input", @old_content || "")
        data.each do |entry|
          key = entry[:key]
          if key.end_with?("[]")
            array_key = key.sub(/\[\]$/, "")
            arrays[array_key] ||= 0
            arrays[array_key] += 1
            key = array_key + "[#{arrays[array_key]}]"
          end
          aug.set("/store/#{key}", entry[:value])
        end

        aug.text_retrieve(@lense, "/input", "/store", "/output")

        return aug.get("/output")
      end
    end
  end
end

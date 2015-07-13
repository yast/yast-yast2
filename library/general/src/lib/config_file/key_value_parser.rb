module ConfigFile
  class KeyvalueParser
    def self.parse(raw_string)
      previous_comments = []
      raw_string.lines.each_with_object({}) do |line, res|
        line = line.strip
        case line
        when /^# .*$/
          previous_comments << line[/^# (.*)$/, 1]
        when /^#\w+=.+$/, /^\w+=.+$/
          name, value = /^#?(\w+)=.+$/.match(line).captures
          res[name] = {
            value: nil,
            comments: previous_comments,
            commented_out: !!(/^#/.match(line))
          }
          previous_comments = []
        when /^\s*$/
          next
        else
          raise "unrecognized line '#{line}'"
        end
      end
    end

    def self.serialize(data)
      data.each_with_object("") do |pair, res|
        key, content = pair
        content[:comments].each do |comment|
          res << "# #{comment}\n"
        end
        prefix = content[:commented_out] ? "#" : ""
        res << "#{prefix}#{key}=#{content[:value]}\n"
      end
    end
  end
end

#!/usr/bin/env ruby
#
# CommentedConfigFile class
#
# (c) 2017 Stefan Hundhammer <Stefan.Hundhammer@gmx.de>
#     Donated to the YaST project
#
# Original project: https://github.com/shundhammer/ruby-commented-config-file
#
# License: GPL V2
#

# Utility class to read and write config files that might contain comments.
# This class tries to preserve any existing comments and keep them together
# with the content line immediately following them.
#
# This class supports the notion of a header comment block, a footer comment
# block, a comment block preceding any content line and a line comment on the
# content line itself.
#
# A comment preceding a content line is stored together with the content line,
# so moving around entries in the file will keep the comment with the content
# line it belongs to.
#
# The default comment marker is '#' like in most Linux config files, but it
# can be set with setCommentMarker().
#
# Example (line numbers added for easier reference):
#
#   001    # Header comment 1
#   002    # Header comment 2
#   003    # Header comment 3
#   004
#   005
#   006    # Header comment 4
#   007    # Header comment 5
#   008
#   009    # Content line 1 comment 1
#   010    # Content line 1 comment 2
#   011    content line 1
#   012    content line 2
#   013
#   014    content line 3
#   015
#   016    content line 4
#   017    content line 5 # Line comment 5
#   018    # Content line 6 comment 1
#   019
#   020    content line 6 # Line comment 6
#   021    content line 7
#   022
#   023    # Footer comment 1
#   024    # Footer comment 2
#   025
#   026    # Footer comment 3
#
#
# Empty lines or lines that have only whitespace belong to the next comment
# block: The footer comment consists of lines 022..026.
#
# The only exception is the header comment that stretches from the start of
# the file to the last empty line preceding a content line. This is what
# separates the header comment from the comment that belongs to the first
# content line. In this example, the header comment consists of lines
# 001..008.
#
# Content line 1 in line 011 has comments 009..010.
# Content line 2 in line 012 has no comment.
# Content line 3 in line 014 has comment 013 (an empty line).
# Content line 5 in line 017 has a line comment "# Line comment 5".
# Content line 6 in line 020 has comments 018..019 and a line comment.
#
# Applications using this class can largely just ignore all the comment stuff;
# the class will handle the comments automagically.
#
class CommentedConfigFile
  include Enumerable

  # @return [Array<Entry>] The config file entries.
  attr_accessor :entries

  # @return [Array<String>] The header comments
  attr_accessor :header_comments

  # @return [Array<String>] The footer comments
  attr_accessor :footer_comments

  # @return [String] The last filename that content was read from.
  attr_reader :filename

  # @return [String] The comment marker; "#" by default.
  attr_accessor :comment_marker

  def initialize
    @comment_marker = "#"
    @header_comments = nil
    @footer_comments = nil
    @entries = []
    @filename = nil
  end

  def header_comments?
    !@header_comments.nil? && !@header_comments.empty?
  end

  def footer_comments?
    !@footer_comments.nil? && !@footer_comments.empty?
  end

  # Provide iterator infrastructure. Together with the Enumerable mixin this
  # provides each, select, reject, map, find, first (but not last) and some
  # more.
  #
  def each(&block)
    @entries.each(&block)
  end

  # Get the last entry. Surprisingly enough, this is not provided by
  # Enumerable.
  #
  # @return [Entry]
  #
  def last
    @entries.last
  end

  def delete_if(&block)
    @entries.delete_if(&block)
  end

  # Return the number of entries
  #
  # @return [Fixnum]
  #
  def size
    @entries.size
  end

  def clear_entries
    @entries = []
  end

  def clear_all
    clear_entries
    @header_comments = nil
    @footer_comments = nil
  end

  # Check if a line is a comment line (not an empty line!).
  #
  # @param line [String] line to check
  # @return [Boolean] true if comment, false otherwise
  #
  def comment_line?(line)
    line =~ /^\s*#{@comment_marker}.*/ ? true : false
  end

  # Check if a line is an empty line, i.e. it is completely empty or it only
  # contains whitespace.
  #
  # @param line [String] line to check
  # @return [Boolean] true if empty, false otherwise
  #
  def empty_line?(line)
    # /m : multi-line mode
    # \z : end of string; different from $ (end of line) in multi-line strings.
    line =~ /^\s*\z/m ? true : false
  end

  # Split a content line into the real content and any potential line comment:
  # "foo = bar   # baz" -> ["foo=bar", "# baz"]
  #
  # The content is also stripped of any leading and trailing whitespace.
  # The line comment, if present, contains the leading comment marker.
  #
  # @param line [String]
  # @return [Array<String>] [content, comment]
  #
  def split_off_comment(line)
    match = /^(.*)(#{comment_marker}.*)/.match(line)
    return [line.strip, nil] if match.nil?

    content = match[1]
    comment = match[2]

    [content.strip, comment]
  end

  # Parse lines: Split the file content up between header comment, content,
  # footer content. Parse each content line, breaking it up into its comment
  # before each entry, the content itself and the line comment.
  #
  def parse(lines)
    clear_all
    header_end = store_header_comments(lines)
    footer_start = store_footer_comments(lines, header_end + 1)

    # We need to just store the header and footer comments and leave 'lines'
    # untouched so any error handling in the parser can return the real line
    # numbers of an error; if we would split off the comments, those line
    # numbers would be off.

    parse_entries(lines, header_end + 1, footer_start - 1)
  end

  # Format the complete file content into separate lines, including header and
  # footer comments. This is the reverse operation of 'parse'.
  #
  # @return [Array<String>] formatted content
  #
  def format_lines
    lines = []
    lines.concat(@header_comments) if header_comments?
    lines.concat(format_entries)
    lines.concat(@footer_comments) if footer_comments?
    lines
  end

  # Format only the entries without header or footer comments, but with
  # comments before each entry and with the line comments.
  #
  # @return [Array<String>] formatted entries
  #
  def format_entries
    lines = []
    each do |entry|
      lines.concat(entry.comment_before) if entry.comment_before?
      content_line = entry.format
      content_line += " " + entry.line_comment if entry.line_comment?
      lines << content_line
    end
    lines
  end

  # Format the complete file content into a single multi-line string.
  #
  # @return [String] formatted content
  #
  def to_s
    format_lines.join("\n")
  end

  # Read a file and parse it.
  #
  # @param filename [String]
  #
  def read(filename)
    @filename = filename
    lines = []
    open(filename).each { |line| lines << line.chomp }
    parse(lines)
  end

  # Write the stored content to a file. If no filename is specified, reuse the
  # filename the content was read from.
  #
  # @param filename [String]
  #
  def write(filename = nil)
    filename ||= @filename
    open(filename, "w") do |file|
      format_lines.each { |line| file.puts(line) }
    end
  end

  # Create a new entry.
  #
  # Derived classes might choose to override this and return an instance of
  # their own entry class.
  #
  # @return [CommentedConfigFile::Entry] new entry
  #
  def create_entry
    Entry.new(self)
  end

  protected

  # Parse the entries in 'lines'. Header and footer comments should already
  # removed from 'lines'.
  #
  # This will create a new Entry object for each content line and add it to the
  # internal array of entries.
  #
  # @param lines [Array<String>]
  # @param from [Fixnum] line number of the first line to parse
  # @param to   [Fixnum] line number of the last  line to parse
  #
  # @return [Boolean] true if success, false if error
  #
  def parse_entries(lines, from, to)
    clear_entries
    comment_before = []
    success = true

    for line_no in from..to
      line = lines[line_no]
      if empty_line?(line) || comment_line?(line)
        comment_before << line
      else # found a content line
        entry = create_entry
        entry.comment_before = comment_before unless comment_before.empty?
        comment_before = []
        content, entry.line_comment = split_off_comment(line)
        if entry.parse(content, line_no)
          @entries << entry
        else
          success = false
        end
      end
    end
    success
  end

  # Identify the header comments from 'lines' and store them in
  # 'header_comments'. Leave 'lines' untouched.
  #
  # @param lines [Array<String>]
  # @return [Fixnum] header end
  #
  def store_header_comments(lines)
    header_end = find_header_comment_end(lines)
    @header_comments = lines.slice(0, header_end + 1)
    header_end
  end

  # Identify the footer comments from 'lines' and store them in
  # 'footer_comments'. Leave 'lines' untouched.
  #
  # @param lines [Array<String>]
  # @return [Fixnum] footer start
  #
  def store_footer_comments(lines, from)
    footer_start = find_footer_comment_start(lines, from)
    footer_length = lines.size - footer_start
    @footer_comments = lines.slice(footer_start, footer_length)
    footer_start
  end

  # Find the line number of the end of the header comment.
  #
  # @param lines [Array<String>]
  # @return [Fixnum] line number or -1 if there is no header comment
  #
  def find_header_comment_end(lines)
    header_end = -1
    last_empty_line = -1

    lines.each_with_index do |line, i|
      if empty_line?(line)
        last_empty_line = i
      elsif comment_line?(line)
        header_end = i
      else # found the first content line
        break
      end
    end

    if last_empty_line > 0
      header_end = last_empty_line
      # This covers two cases:
      #
      # - If there were empty lines and no more comment lines before the
      #   first content line, the empty lines belong to the header comment.
      #
      # - If there were empty lines and then some more comment lines before
      #   the first content line, the comments after the last empty line no
      #   longer belong to the header comment, but to the first content
      #   entry. So let's go back to that last empty line.
    end

    header_end
  end

  # Find the line numer of the first line of the footer comment.
  #
  # @param lines [Array<String>]
  # @return [Fixnum] line number or lines.size if there is no footer comment
  #
  def find_footer_comment_start(lines, from)
    footer_start = lines.size

    lines.reverse_each.each_with_index do |line, i|
      line_no = lines.size - 1 - i
      break if line_no < from
      break unless empty_line?(line) || comment_line?(line)
      footer_start = line_no
    end

    footer_start
  end

  # Class representing one content line and the preceding comments.
  #
  # When subclassing this, don't forget to also overwrite
  # CommentedConfigFile::create_entry!
  #
  class Entry
    # @return [CommentedConfigFile] The parent CommentedConfigFile.
    #
    # While this base class does not really use the parent, derived classes
    # will so they can access data from their parent config file.
    attr_accessor :parent

    # @return [String] Content without any comment.
    attr_accessor :content

    # @return [Array<String>] Comment lines before the entry.
    attr_accessor :comment_before

    # @return [String] Comment on the same line as the entry (without trailing
    # newline).
    attr_accessor :line_comment

    # Constructor.
    #
    # @param parent [CommentedConfigFile]
    #
    def initialize(parent = nil)
      @parent = parent
      @content = nil
      @comment_before = nil
      @line_comment = nil
    end

    def comment_before?
      !@comment_before.nil? && !@comment_before.empty?
    end

    def line_comment?
      !@line_comment.nil? && !@line_comment.empty?
    end

    # Parse a content line. This expects any line comment and the newline to be
    # stripped off already.
    #
    # Derived classes might choose to override this.
    #
    # @param line [String] content line without any line comment
    # @param line_no [Fixnum] line number for error reporting
    #
    # @return [Boolean] true if success, false if error
    #
    def parse(line, _line_no = -1)
      @content = line
      true
    end

    # Format the content (without the line comment) as a string.
    # Derived classes might choose to override this.
    #
    # @return [String] formatted line without line comment.
    #
    def format
      content
    end

    alias_method :to_s, :format
  end
end

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

require "yast2/commented_config_file"

# Utility class to read and write column-oriented config files that might
# contain comments that should be preserved when writing the file.
#
# One example for this would be /etc/fstab:
#
#    # /etc/fstab
#    #
#    # <file system>	<mount point>  <type> <options>	    <dump> <pass>
#
#    /dev/disk/by-label/swap	 none	swap  sw		 0  0
#    /dev/disk/by-label/Ubuntu	 /	ext4  errors=remount-ro	 0  1
#    /dev/disk/by-label/work	 /work	ext4  defaults		 0  2
#
# There are 6 columns, separated by whitespace. This class is a refinement of
# the more generic CommentedConfigFile class to handle such cases.
#
class ColumnConfigFile < CommentedConfigFile
  DEFAULT_MAX_COLUMN_WIDTH = 40
  DEFAULT_INPUT_DELIMITER = /\s+/
  DEFAULT_OUTPUT_DELIMITER = "  ".freeze

  # @return [Fixnum] the fallback value for the maximum column width if no
  # per-column value is specified for a column.
  #
  attr_accessor :fallback_max_column_width

  # @return [Array<Fixnum>] Per-column maximum width for each column. If not
  # specified for a column, 'fallback_max_column_width' is used.
  #
  attr_accessor :max_column_widths

  # @return [Boolean] Flag: Pad the columns to a common width (up to each
  # column's maximum width) or not?
  #
  attr_accessor :pad_columns

  # @return [Regexp] Input column delimiter, used for parsing content lines.
  # This is usually one or more whitespace characters, but it might also be
  # something completely different like one colon for /etc/passwd.
  #
  # If this is non-blank, pad_columns should probably also set to 'false'
  # because it will always pad with blanks which would probably not be
  # appropriate for that file format.
  attr_accessor :input_delimiter

  # @return [String] Output column delimiter; this is used when formatting
  # columns. The default is " " (two blanks).
  attr_accessor :output_delimiter

  # @return [Array<Fixnum>] The last column widths calculated.
  #
  attr_reader :column_widths

  def initialize
    super
    @max_column_widths = []
    @fallback_max_column_width = DEFAULT_MAX_COLUMN_WIDTH
    @pad_columns = true
    @input_delimiter = DEFAULT_INPUT_DELIMITER
    @output_delimiter = DEFAULT_OUTPUT_DELIMITER
    @column_widths = []
  end

  # Format only the entries without header or footer comments, but with
  # comments before each entry and with the line comments.
  #
  # Reimplemented from CommentedConfigFile.
  #
  # @return [Array<String>] formatted entries
  #
  def format_entries
    populate_columns
    calc_column_widths
    super
  end

  # Get the column with for one column.
  # If padding is not enabled, this returns 0.
  #
  # @param column_no [Fixnum] number of the column (from 0)
  #
  # @return [Fixnum] column width
  #
  def get_column_width(column_no)
    return 0 unless @pad_columns
    calc_column_widths if @column_widths.empty?
    @column_widths[column_no] || 0
  end

  # Get the maximum column with for a column.
  #
  # @param column_no [Fixnum] number of the column (from 0)
  #
  # @return [Fixnum] column width
  #
  def get_max_column_width(column_no)
    @max_column_widths[column_no] || @fallback_max_column_width
  end

  # If @pad_columns is set, calculate the best column widths for all columns
  # and store the result in @column_widths.
  #
  # @return [Array<Fixnum>] column widths
  #
  def calc_column_widths
    return [] unless @pad_columns
    @column_widths = []

    for col in 0...count_max_columns
      @column_widths[col] = calc_column_width(col)
    end
    @column_widths
  end

  # Create a new entry.
  #
  # Reimplemented from CommentedConfigFile.
  #
  # @return [ColumnConfigFile::Entry] new entry
  #
  def create_entry
    ColumnConfigFile::Entry.new(self)
  end

  protected

  # Count the maximum number of columns amont all entries.
  #
  # @return [Fixnum]
  #
  def count_max_columns
    reduce(0) { |old_max, entry| [old_max, entry.columns.size].max }
  end

  # Populate all columns of all entries.
  #
  # This is intended for derived entry classes to copy their internal content
  # to the columns just prior to formatting output.
  #
  def populate_columns
    each(&:populate_columns)
  end

  # Find the maximum column width for one column, limited by that column's
  # maximum width.
  def calc_column_width(column_no)
    max_width = get_max_column_width(column_no)

    reduce(0) do |old_max, entry|
      col = entry.columns[column_no]
      next old_max if col.nil? # This entry doesn't have that many columns

      # Only take the width of this column of this entry into account if it is
      # not wider than the maximum for this column; otherwise we will always
      # end up with the maximum width for any column that has just one item the
      # maximum width, but for that one item the maximum will be exceeded
      # anyway (otherwise we'd have to cut if off which we clearly can't). So
      # oversize column items should not be part of this calculation; we want
      # to know the widths of the "normal" items only.

      if col.size > max_width && max_width > 0
        old_max
      else
        [col.size, old_max].max
      end
    end
  end

  # Class representing one content line with all its columns and the preceding
  # comments.
  #
  # When subclassing this, don't forget to also overwrite
  # ColumnConfigFile::create_entry!
  #
  class Entry < CommentedConfigFile::Entry
    attr_accessor :columns

    # Constructor. Notice that while the parent class does not really do
    # anything with the parent, this class does, so it is important to set it.
    #
    # @param parent [ColumnConfigFile]
    #
    def initialize(parent)
      super
      @columns = []
    end

    # Parse a content line. This expects any line comment and the newline to be
    # stripped off already.
    #
    # Reimplemented from CommentedConfigFile::Entry.
    #
    # @param line [String] content line without any line comment
    # @param line_no [Fixnum] line number for error reporting
    #
    # @return [Boolean] true if success, false if error
    #
    def parse(line, _line_no = -1)
      super
      @columns = line.split(input_delimiter)
      true
    end

    # Format the content (without the line comment) as a string.
    # Derived classes might choose to override this.
    #
    # Reimplemented from CommentedConfigFile::Entry.
    #
    # @return [String] formatted line without line comment.
    #
    def format
      line = ""
      @columns.each_with_index do |_col, i|
        line << output_delimiter unless line.empty?
        line << pad_column(i)
      end
      line
    end

    # Populate the columns. This is called just prior to calculating the column
    # widths and formatting the columns. Derived classes can use this to fill
    # the columns with values from any other fields.
    #
    # This default implementation does nothing.
    #
    def populate_columns
    end

    # String conversion, mostly for debugging.
    #
    # Make sure that the columns are updated: Derived classes (e.g. EtcFstab)
    # typically operate on data members that are parsed from the individual
    # columns, so we need to give the derived class a chance to update the
    # columns from those data members to get meaningful output.
    #
    # @return [String]
    #
    def to_s
      populate_columns
      format
    end

    protected

    # Return the column delimiter used for input (parsing).
    #
    # @return [Regexp] delimiter
    #
    def input_delimiter
      return DEFAULT_INPUT_DELIMITER unless parent && parent.respond_to?(:input_delimiter)
      parent.input_delimiter
    end

    # Return the column delimiter used for output, usually two blanks.
    #
    # @return [String] delimiter
    #
    def output_delimiter
      return DEFAULT_OUTPUT_DELIMITER unless parent && parent.respond_to?(:output_delimiter)
      parent.output_delimiter
    end

    # Pad column no. 'column_no' to the desired witdh.
    #
    # @param [Fixnum] column_no
    #
    # @return [String] padded column text
    #
    def pad_column(column_no)
      col = @columns[column_no]
      return col unless parent && parent.respond_to?(:pad_columns)
      return col unless parent.pad_columns
      col.ljust(parent.get_column_width(column_no), " ")
    end
  end
end

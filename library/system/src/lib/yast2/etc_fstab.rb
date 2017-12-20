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

require "yast2/column_config_file"

# Class to handle /etc/fstab of a Linux/Unix system.
#
# This includes parsing and formatting, accessing and modifying entries,
# maintaining the correct order between them (since they might have
# dependencies between mount points) and keeping comments in the file intact
# (see the CommentedConfigFile and ColumnConfigFile base classes).
#
# Use the "entries" member variable (inherited from CommentedConfigFile) to
# access the entries.
#
# To add a new entry, it is strongly advised to use add_entry from this class
# rather than just appending an entry via the inherited "entries" member:
# add_entry takes care of the correct order of mount points in case there are
# depencencies.
#
# For example, an entry for /var/lib/myapp should appear AFTER the entry for
# /var/lib, otherwise /var/lib (if mounted after /var/lib/myapp) would shadow
# the already mounted /var/lib/myapp which is typically not desired.
#
# Important / useful inherited methods:
# read, write, parse, format;
# each, select, reject, map, first, last, delete_if
#
class EtcFstab < ColumnConfigFile
  # The usual name of that file
  ETC_FSTAB = "/etc/fstab".freeze

  # Constructor.
  #
  # @param filename [String] File to read if specified.
  #
  def initialize(filename = nil)
    super()
    @max_column_widths = [45, 25, 8, 30, 1, 1]
    @pad_columns = true

    # /etc/fstab does not support end-of-line comments.
    #
    # There might be a literal '#' character somewhere, though, in particular
    # in the mount options.
    @line_comments_enabled = false

    read(filename) unless filename.nil?
  end

  # Add an entry. The entry can be created with EtcFstab::Entry.create_entry or
  # with plain EtcFstab::Entry.new; it will always be reparented to this
  # EtcFstab instance.
  #
  # It is strongly advised to use this add_entry method rather than just
  # appending an entry via the inherited "entries" member: add_entry takes care
  # of the correct order of mount points in case there are depencencies:
  #
  # For example, an entry for /var/lib/myapp should appear AFTER the entry for
  # /var/lib, otherwise /var/lib (if mounted after /var/lib/myapp) would shadow
  # the already mounted /var/lib/myapp which is typically not desired.
  #
  # @param entry [EtcFstab::Entry]
  #
  def add_entry(entry)
    raise ArgumentError, "Trying to add nil entry" if entry.nil?
    entry.parent = self
    index = find_sort_index(entry)
    @entries.insert(index, entry)
  end

  # Return all devices in this fstab in the order in which they appear.
  #
  # @return [Array<String>]
  #
  def devices
    map(&:device)
  end

  # Return all mount points in this fstab in the order in which they appear.
  #
  # @return [Array<String>]
  #
  def mount_points
    map(&:mount_point)
  end

  # Return all filesystem types in this fstab in the order in which they appear.
  #
  # This does not filter out duplicates; use Array::uniq on the result if this
  # is desired.
  #
  # @return [Array<String>]
  #
  def fs_types
    map(&:fs_type)
  end

  # Find the (first) entry with the specified mount point. Return nil if there
  # is no such entry.
  #
  # @param mount_point [String]
  #
  # @return [EtcFstab::Entry, nil]
  #
  def find_mount_point(mount_point)
    find { |entry| entry.mount_point == mount_point }
  end

  # Find the (first) entry with the specified device. Return nil if there
  # is no such entry.
  #
  # @param device [String]
  #
  # @return [EtcFstab::Entry, nil]
  #
  def find_device(device)
    find { |entry| entry.device == device }
  end

  # Check the mount order of all the entries, i.e. if all entries are listed
  # after any mount points they depend on. Call fix_mount_order to fix the
  # problem.
  #
  # For example, if an entry for /var/lib/myapp appears before the entry for
  # /var/lib, the /var/lib would shadow /var/lib/myapp, so this method would
  # return 'false'.
  #
  # @return [Boolean] 'true' if okay, 'false' if there are mount order problems.
  #
  def check_mount_order
    next_mount_order_problem == -1
  end

  # Fix any mount order problems: Make sure the entries are listed in the
  # correct order.
  #
  # For example, if an entry for /var/lib/myapp appears before the entry for
  # /var/lib, the /var/lib would shadow /var/lib/myapp. This method fixes this
  # if possible.
  #
  # Notice that it is still possible that some problems cannot be fixed (in
  # which case this method returns 'false'): For example, if somebody edited
  # /etc/fstab manually and added the same mount point for two entries. This is
  # wrong, but this cannot be fixed automatically (we'd have to decide which
  # one to remove). Don't call this again and again if there are such unfixable
  # problems.
  #
  # @return [Boolean] 'true' if all problems are fixed, 'false' if not
  #
  def fix_mount_order
    reordered = []
    start_index = 0
    success = true

    while start_index < @entries.size
      # problem_index = next_mount_order_problem(start_index)
      problem_index = next_mount_order_problem(start_index)
      return success if problem_index == -1 # No more problem -> we are finished.

      entry = @entries[problem_index]
      if reordered.include?(entry)
        # We already reordered this entry. This should not happen, but now we
        # have to prevent an endless loop; so let's skip over this entry now.
        start_index = problem_index + 1
        success = false

        # There is one pathological case where this could happen:
        #
        # When two or more entries have the same mount point (which is illegal,
        # but somebody might write such an fstab manuallly), there is no
        # correct mount order; this algorithm would get into an endless loop if
        # we now checked the same index again. But by just proceeding with the
        # next one (and silently assuming that the one we just changed is well
        # and truly fixed), we can avoid that endless loop.
        #
        # The fstab is of course still incorrect, but there is nothing we can
        # do about that at this point.
      else
        # Take this entry out of the entries and put it back at the correct
        # place.
        @entries.delete_at(problem_index)
        add_entry(entry)

        # Keep track of the reordered entries to avoid an endless loop
        reordered << entry
      end
    end
    success
  end

  # Find the the entry index of the next mount order problem starting from
  # 'start_index' or -1 if there is no more.
  #
  # @param start_index [Fixnum]
  #
  # @return [Fixnum] Next problematic entry index or -1 if no more problems
  #
  def next_mount_order_problem(start_index = 0)
    each_with_index do |entry, index|
      next if index < start_index
      sort_index = find_sort_index(entry)
      next if sort_index == -1
      return index if sort_index < index
    end
    -1
  end

protected

  # Find the correct index for an entry if it depends on any other entry or -1
  # if no other entry depends on this one, i.e. it can safely added to the end
  # of the list.
  #
  # @param new_entry [EtcFstab::Entry]
  #
  # @return [Fixnum] correct index or -1 if there is no dependency
  #
  def find_sort_index(new_entry)
    mount_point = new_entry.mount_point
    each_with_index do |entry, index|
      next if entry.equal?(new_entry)
      next if entry.mount_point.nil?
      return index if entry.mount_point.start_with?(mount_point)
    end
    -1
  end

public

  # Get the "mount by" type of a device entry in /etc/fstab.
  # See also EtcFstab::Entry.get_mount_by.
  #
  # @param device [String] device field or complete entry line
  # @return [Symbol] One of :uuid, :label, :id, :path, :device
  #
  def self.get_mount_by(device)
    case device
    when /^UUID=/, %r{^/dev/disk/by-uuid/}
      :uuid
    when /^LABEL=/, %r{^/dev/disk/by-label/}
      :label
    when %r{^/dev/disk/by-id/}
      :id
    when %r{^/dev/disk/by-path/}
      :path
    else
      :device
    end
  end

  # Encode an fstab entry. It may sound surprising, but the file format
  # actually allows space characters in certain places, such as the mount
  # point; the reasoning is that a space character is a permitted character in
  # a directory name, so there has to be a way to specify such a path without
  # breaking the file format. According to "man fstab", this is done by
  # encoding the space character in octal, i.e. as \040. This is the function
  # to do it.
  #
  # This class and the corresponding entry class handles this transparently, so
  # this should never be necessary to use from the outside.
  #
  # @param unencoded [String] String with possible space characters
  # @return [String] String with space characters replaced by \040
  #
  def self.fstab_encode(unencoded)
    return "" if unencoded.nil?
    unencoded.gsub(" ", '\\\\040')
    # We need four (!) backslashes here because otherwise gsub will assume this
    # is a back-reference to a grouped regexp part in the search expression:
    # \\1 would be the first (..) group, \\2 the second etc.
  end

  # Decode an fstab entry. This is the inverse operation to fstab_encode.
  #
  # @param encoded [String] String with possible \040 sequences
  # @return [String] String with \040 replaced by a space character each
  #
  def self.fstab_decode(encoded)
    return "" if encoded.nil?
    encoded.gsub('\\040', " ")
    # Unlike in fstab_encode, only two backslashes are needed here because it
    # is in the original expression, so it cannot be a back-reference.
  end

  # Create a new entry.
  #
  # Reimplemented from CommentedConfigFile.
  #
  # @param args [Hash] or [Array]
  #
  # @return [ColumnConfigFile::Entry] new entry
  #
  def create_entry(*args)
    entry = EtcFstab::Entry.new(*args)
    entry.parent = self
    entry
  end

  #
  #----------------------------------------------------------------------
  #
  #
  # Entry class for /etc/fstab. This gives each field it semantics rather than
  # just being numbered columns like in the ColumnConfigFile superclass.
  #
  class Entry < ColumnConfigFile::Entry
    # The columns of each EtcFstab entry; see also "man fstab".
    #
    # @return [String] The device that is mounted, including prefixes like
    # "UUID=" or "LABEL=".
    attr_accessor :device

    # @return [String] The mount point where the device is mounted.
    #
    # This value may contain space characters (because space is a permitted
    # character in directory names). In the file, those are escaped with
    # '\040'. This escaping is handled by the parse and format methods of this
    # class, so don't attempty to do it again when setting or getting this
    # value.
    attr_accessor :mount_point

    # @return [String] The filesystem type as specified in /etc/fstab,
    # i.e. lowercase; typically one of "ext2", "ext3", "btrfs", "xfs", "nfs",
    # "vfat" etc.
    attr_accessor :fs_type

    # @return [Array<String>] The mount options, split up in their individual
    # comma-separated parts. This does not ever contain "default"; in that
    # case, the array is empty. The parser and formatter take care of removing
    # or adding "default" if necessary (i.e., when the mount options are
    # empty).
    attr_accessor :mount_opts

    # @return [Fixnum] This field is pretty much obsolete; it was there for the
    # sake of the long obsolete Unix "dump" command, a very old backup
    # tool. This field is (almost?) always 0 nowadays.
    attr_accessor :dump_pass

    # @return [Fixnum] The filesystem check pass. This is typically 1 for the
    # root filesystem, 2 for most others and 0 if no filesystem check should
    # ever be performed on this device (typically for networked devices such as
    # NFS or CIFS (Samba)).
    attr_accessor :fsck_pass

    # Constructor: Create a new Entry either empty or from a hash or from an
    # array.
    #
    # Use a hash with keys :device, :mount_point, :fs_type, :mount_opts,
    # :dump_pass, :fsck_pass, :comment_before to fill the corresponding
    # fields. All keys are optional.
    #
    # Use an array with the same meaning as in /etc/fstab to fill the
    # corresponding fields: device, mount_point, fs_type, mount_opts,
    # dump_pass, fsck_pass.
    #
    # In either case, mount_opts can be specified as a string (in which case it
    # will be parsed just like when it is read from file, removing "defaults"
    # in the process), or as an array.
    #
    # Of course, you can always create the entry empty and use the accessors to
    # set values.
    #
    # @param args [Hash] or [Array]
    #
    def initialize(*args)
      super(nil)
      @device = nil
      @mount_point = nil
      @fs_type = nil
      @mount_opts = []
      @dump_pass = 0
      @fsck_pass = 0

      return if args.empty?

      if args.first.is_a?(Hash)
        from_hash(args.first)
      elsif args.first.is_a?(Array)
        from_array(args.first)
      else
        from_array(args)
      end
    end

    # Initialize an entry from a hash.
    # The mount options can be specified as an array or as a string.
    #
    # @param args [Hash]
    #
    def from_hash(args)
      @device         = args[:device] || @device
      @mount_point    = args[:mount_point] || @mount_point
      @fs_type        = args[:fs_type] || @fs_type
      @dump_pass      = args[:dump_pass] || @dump_pass
      @fsck_pass      = args[:fsck_pass] || @dump_pass
      @comment_before = args[:comment_before] || @comment_before

      return unless args.key?(:mount_opts)

      @mount_opts = args[:mount_opts]
      parse_mount_opts(@mount_opts) if @mount_opts.is_a?(String)
    end

    # Initialize an entry from an array.
    #
    # The order in the array is the same as in /etc/fstab;
    # the array may contain 1..6 elements.
    #
    # The mount options can be specified as a sub-array or as a string.
    #
    # @param args [Array]
    #
    def from_array(args)
      args = args.dup
      @device      = args.shift unless args.empty?
      @mount_point = args.shift unless args.empty?
      @fs_type     = args.shift unless args.empty?

      if !args.empty?
        @mount_opts = args.shift
        parse_mount_opts(@mount_opts) if @mount_opts.is_a?(String)
      end

      @dump_pass = args.shift unless args.empty?
      @fsck_pass = args.shift unless args.empty?
    end

    # Convert to an array in the same order as in /etc/fstab.
    # mount_opts remains an array (and without "defaults").
    #
    # @return [Array]
    #
    def to_a
      [@device, @mount_point, @fs_type, @mount_opts, @dump_pass, @fsck_pass]
    end

    # Convert to a hash with keys :device, :mount_point, :fs_type,
    # :mount:opts, :dump_pass, :fsck_pass.
    #
    # mount_opts remains an array (and without "defaults").
    #
    # @return [Hash]
    #
    def to_h
      {
        device:      @device,
        mount_point: @mount_point,
        fs_type:     @fs_type,
        mount_opts:  @mount_opts,
        dump_pass:   @dump_pass,
        fsck_pass:   @fsck_pass
      }
    end

    # Parse a content line. This expects any line comment and the newline to be
    # stripped off already.
    #
    # Reimplemented from ColumnConfigFile::Entry.
    #
    # @param line [String] content line without any line comment
    # @param line_no [Fixnum] line number for error reporting
    #
    # @return [Boolean] true if success, false if error
    #
    # @raise [EtcFstab::ParseError] Incorrect file format
    #
    def parse(line, line_no = -1)
      super
      if @columns.size != 6
        msg = "Wrong number of columns"
        msg += " in line #{line_no + 1}" if line_no >= 0
        raise EtcFstab::ParseError, msg
      end
      decoded_col = @columns.map { |col| EtcFstab.fstab_decode(col) }
      @device, @mount_point, @fs_type, opt, @dump_pass, @fsck_pass = decoded_col
      parse_mount_opts(opt)
      @dump_pass = @dump_pass.to_i
      @fsck_pass = @fsck_pass.to_i
      true # success
    end

    # Sanity check for an entry. This may throw an InvalidEntryError.
    def sanity_check
      raise InvalidEntryError, "No device specified" if @device.to_s.empty?
      raise InvalidEntryError, "No mount point specified" if @mount_point.to_s.empty?
      raise InvalidEntryError, "No filesystem type specified" if @fs_type.to_s.empty?
    end

    # Populate the columns: Fill the columns with values from the other fields.
    #
    # This is called just prior to calculating the column widths and formatting
    # the columns.
    #
    # Reimplemented from ColumnConfigFile::Entry.
    #
    def populate_columns
      sanity_check
      @columns =
        [@device,
         @mount_point,
         @fs_type,
         format_mount_opts,
         @dump_pass.to_s,
         @fsck_pass.to_s]

      # Strictly speaking, space characters are only permitted in the
      # mount_point column according to "man fstab". But better be safe than
      # sorry; there might be a space character also in a device label or in
      # the mount options, and if the kernel / the mount command / systemd can
      # handle it, we want to support that, too; so let's simply encode all the
      # fields.
      #
      # On the downside, this does not let us strip all the other fields
      # because we might strip away a space character that was intentional; so
      # it's the caller's responsibility to make sure that there are no
      # unintended space characters in any of the fields.

      @columns.map! { |col| EtcFstab.fstab_encode(col) }
    end

    # Get the "mount_by" type of this entry. See EtcFstab::get_mount_by.
    #
    # @return [Symbol]
    #
    # Rubocop thinks this is an accessor, but it's not
    # rubocop:disable Style/AccessorMethodName
    #
    def get_mount_by
      EtcFstab.get_mount_by(@device)
    end
    # rubocop:enable Style/AccessorMethodName

    # Parse a mount options field and store the result in @mount_opts.
    #
    # This removes any occurrence of "defaults" (which really only makes sense
    # if the field would otherwise be empty which is not permitted by the file
    # format).
    #
    # @param opts [String] mount options field
    #
    def parse_mount_opts(opts)
      if opts.nil?
        @mount_opts = []
        return
      end
      @mount_opts = opts.split(/,/)
      @mount_opts.delete_if { |opt| opt == "defaults" }
    end

    # Format the mount options from @mount_opts. If they are empty (and only
    # then) this returns "defaults" to make sure the file format is still
    # intact.
    #
    # @return [String] Formatted mount options
    #
    def format_mount_opts
      return "defaults" if @mount_opts.empty?
      @mount_opts.join(",")
    end

    # Return the column delimiter used for input (parsing).
    #
    # Reimplemented from ColumnConfigFile::Entry.
    #
    # @return [Regexp] delimiter
    #
    def input_delimiter
      ColumnConfigFile::DEFAULT_INPUT_DELIMITER
    end
  end

  # Error class for parsing
  class ParseError < RuntimeError
  end

  # Error class for invalid entries
  class InvalidEntryError < RuntimeError
  end
end

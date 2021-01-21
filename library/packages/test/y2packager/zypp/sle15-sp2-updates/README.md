The testing data was downloaded from the [bsc#1178688](
https://bugzilla.suse.com/show_bug.cgi?id=1178688) bug report.

The data was manually modified:

- Only the `primary.xml.gz` is used
- Removed the `weakremover` dependencies (decreases the uncompressed data size
  from ~1MB to ~15kB (!) and makes the XML parsing much faster)
- Changed the product architecture to `noarch` to allow running the test also on
  non-x86_64 machines

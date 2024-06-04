When building a disk image software distribution, it's nice to make a certain directory (usually the root directory of the volume) automatically open a Finder window when the disk image is
mounted.  In years past, one could do that using the command line tool `bless` with the `--openfolder` option.  But now, the `--openfolder` option is deprecated, and may not entirely work.
This tool attempts to do the equivalent, using undocumented fields in the Finder info of the volume.  At present, it works with volumes using the HFS+ (Mac OS Extended) file system, but
not volumes using the APFS file system.

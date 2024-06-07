When building a disk image software distribution, it's nice to make a certain directory (usually the root directory of the volume) automatically open a Finder window when the disk image is
mounted.  In years past, one could do that using the command line tool `bless` with the `--openfolder` option.  But now, the `--openfolder` option is deprecated, and does not seem to work.
This command line tool attempts to do the equivalent, by modifying a field in the Finder info of the volume.  It works with volumes using the HFS+ (Mac OS Extended) file system, but
not volumes using other file systems such as APFS.

Usage:

```
SetDmgOpenFolder [--verbose] path-to-folder-on-mounted-writable-disk-image
```

There is a different way to create a read-only disk image that automatically opens a particular folder:

```
sudo hdiutil makehybrid -hfs -hfs-openfolder open-path -o output-path source-path
```

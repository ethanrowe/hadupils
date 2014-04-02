
### 0.1.0

* Basic functionality for representing a command, extensions,
  assets, runners.
* A hive runner enforcing user config and hadoop-ext extension
* A hadupils executable for entering the command model

### 0.1.1

* Removed evil rubygems requirement from executable
* Added this glorious changelog

### 0.1.2

* Fixed embarrassing mispelling of "shoulda-context" in gemspec
  development dependencies

### 0.1.3

* Fixed compat. issue for ruby 1.8; downcase on symbol is a no-no.
  In Hadupils::Command module.

### 0.2.0

* Introduced hive extensions (hive-ext)
* Hive command uses hive extensions to assemble hivercs
* Hive command assembles HIVE_AUX_JARS_PATH variable
* Base runner can handle environment variable hash as first command
  parameter (custom support for pre-1.9 ruby, the Kernel.system call
  of which does not handle such things)

### 0.3.0

* Introduced Hadupils::Extensions::FlatArchivePath
* The "hive" command uses a FlatArchivePath for hadoop-ext instead
  of Flat, so PATH will include bin dirs of any hadoop-ext archives
  when a streaming query runs.
* Some misc. utility functions in Hadupils::Util for reading tarballs.

### 0.4.0

* Introduced Hadupils::Extensions::Hive.build_archive
  Helper method for assembling gzipped archives the contents of which
  are hive-ext compatible.

### 0.5.0

* Introduced a hadoop command enforcing user config and hadoop-ext
  configuration files (hadoop.xml) that calls the hadoop runner
* Introduced the following commands and runners that utilize the hadoop
  runner (to work against the DFS): mktemp, withtmpdir and rm
* Support for hadoop_confs in Hadupils::Extensions
* Introduced Hadupils::Extensions::Dfs::TmpFile
* Introduced Hadupils::Hacks module for String Refinements (self.randcase)
  for Ruby 2+ and Monkey Patching for the String class for Ruby < 2.0
* Introduced $HADUPILS_BASE_TMP_PATH and $HADUPILS_TMPDIR_PATH for use with
  commands: mktemp, withtmpdir and rm
* Some refactoring and fixed a bug with the specs for Mac OS X
* Tweaked old unit tests and added new ones for the new features
* Updated the README with examples

### 0.6.0

* Renamed $HADUPILS_BASE_TMP_PATH to $HADUPILS_TMP_PATH (less typing)
* Introduced $HADUPILS_TMP_TTL for use with command: cleanup
* Introduced Hadupils::Commands::Cleanup to identify and remove old hadupils tmp DFS
  directories/files where all files within any hadupils-tmpdir* in $HADUPILS_TMP_PATH
  are older than $HADUPILS_TMP_TTL, the TTL (Time.now.utc - $HADUPILS_TMP_TTL)
* The Hadupils::Runnders::Base.new.execute! method now uses Open3.capture2 or Kernel.system
* Fixed 1.8.7 compatibility bug with the Kernel.system call in
  Hadupils::Extensions::Hive::AuxJarsPath.build_archive
* Some refactoring

### 0.6.1

* Fixed weird bug in Hadupils::Extensions::Hive.build_archive; the call
  was hanging reading from stderr, which isn't strictly necessary anyway.
  Now it no hangy.

### 0.6.2
* Stopped the hadupils cleanup command from outputting 'Removing...' to STDOUT when it
  doesn't have anything to actually remove.


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


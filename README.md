hadupils
========

Operating environment oriented utilities for hadoop (Hadoop + Utils => hadupils)

## Shell Environment Variables
- $HADUPILS_BASE_TMP_PATH
    * This is the base path for DFS temporary file/directory creation
    * Defaults to '/tmp' on the DFS (only set this if you need another base directory)
- $HADUPILS_TMPDIR_PATH
    * Set when the subcommand is executed in a subshell via the hadupils 'withtmpdir' command
    * The value comes from the tmp directory that hadupils created for the subcommand
    * It will cleanup (remove) the directory if the subcommand returns an exitstatus of zero

## Hadpuils' Commands
- hive __command__ _options_
- hadoop __command__ _options_
- mktemp [-d]
- withtmpdir __subshell_command__
- rm [-r] __full_path_to_file_or_directory__

### Example Usages
``` shell
hadupils hive -e 'select a.col from tab1 a'
hadupils hadoop fs -ls /tmp
hadupils mktemp -d
hadupils withtmpdir 'echo $HADUPILS_TMPDIR_PATH'
hadupils rm -r /tmp/hadupils-tmp-e341afe01721013128c122000af92329
```

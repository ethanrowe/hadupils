hadupils
========

Operating environment oriented utilities for hadoop (Hadoop + Utils => hadupils)

## Shell Environment Variables
- $HADUPILS_TMP_PATH
    * This is the base path for DFS temporary file/directory creation
    * Defaults to '/tmp' on the DFS (only set this if you need another base directory)
    * Command 'cleanup' will use this ENV var for the base tmp_path to look for /hadupils-tmp*/
      tmpdirs if the tmp_path isn't set throught the command line
    * Other commands that use this are: mktemp, withtmpdir

- $HADUPILS_TMPDIR_PATH
    * Set when the subcommand is executed in a subshell via the hadupils 'withtmpdir' command
    * The value comes from the tmp directory that hadupils created for the subcommand
    * It will cleanup (remove) the directory if the subcommand returns an exitstatus of zero
- $HADUPILS_TMP_TTL
    * This is the Time-To-Live for hadupils DFS temporary files/directories (hadupils-tmp*)
    * Defaults to '86400' (24 hours)
    * Command 'cleanup' will use this ENV var to remove any /hadupils-tmp*/ tmpdirs within
      $HADUPILS_TMP_PATH where all files within are older than TTL, (Time.now.utc - $HADUPILS_TMP_TTL)
      if ttl isn't set through the command line

## Hadpuils' Commands
- hive __command__ _options_
- hadoop __command__ _options_
- mktemp [-d]
- withtmpdir __subshell_command__
- rm [-rR] __full_path_to_file_or_directory__
- cleanup [-n] __full_path_to_tmp_dir__ __ttl__

### Example Usages
``` shell
hadupils hive -e 'select a.col from tab1 a'
hadupils hadoop fs -ls /tmp
hadupils mktemp -d
hadupils withtmpdir 'echo $HADUPILS_TMPDIR_PATH'
hadupils rm -r /tmp/hadupils-tmp-e341afe01721013128c122000af92329
hadupils cleanup -n
```

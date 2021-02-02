Data File Overrides
-------------------

This directory is intended to be used for substituting the existing copy of a configuration file with a replacement version,
variable substitution is supported by this mechanism using the same approach (envsubst) as the basic server profile. The 
replacement file(s) need to be placed in this directory at the same relative path as they appear within the data directory 
itself.

Changes made here override an existing setting on disk or contained within a configuration backup. Changes made using the
config-store directory will override any changes made to the config store by files in this directory if both reference the 
same setting.  

To use this mechanism you need a copy of the existing file, which might be obtained from downloading and expanding a backup 
archive or copied directly from the server using kubectl's copy command.

Edit the file as appropriate and place it within the data-overrides directory at the same relative location as it appears 
within the data directory. To apply the changes restart the PingFederate admin server and then the engines.


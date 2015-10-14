
## Check for version 2015.3 of Vivado
if { [VersionCheck 2015.3] < 0 } {
   close_project
   exit -1
}

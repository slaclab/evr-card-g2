
## Check for version 2015.2 of Vivado
if { [VersionCheck 2015.2] < 0 } {
   close_project
   exit -1
}

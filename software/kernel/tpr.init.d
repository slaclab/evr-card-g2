#!/bin/bash

### BEGIN INIT INFO
# Provides:          tpr
# Required-Start:    $local_fs $syslog
# Required-Stop:     $local_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Load kernel module and create device nodes at boot time.
# Description:       Load kernel module and create device nodes at boot time for pcie_tpr instruments.
### END INIT INFO


function tpr_start()
{
    /sbin/modprobe tpr || exit 1
    test -e /dev/er[a-z]3 && /bin/rm -f /dev/er[a-z]*
    test -e /dev/tpr[a-z] && /bin/rm -f /dev/tpr[a-z]*
#    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/er%c3 c %d 13\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%cBSA c %d 13\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c c %d 12\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c0 c %d 0\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c1 c %d 1\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c2 c %d 2\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c3 c %d 3\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c4 c %d 4\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c5 c %d 5\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c6 c %d 6\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c7 c %d 7\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c8 c %d 8\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%c9 c %d 9\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%ca c %d 10\n", n++, $1}' /proc/devices`
    `/usr/bin/awk 'BEGIN{n=97;}/tpr/{printf "/bin/mknod -m 666 /dev/tpr%cb c %d 11\n", n++, $1}' /proc/devices`
}


function tpr_stop()
{
    test -e /dev/tpr[a-z] && /bin/rm -f /dev/tpr[a-z]*
}


case "$1" in
    start)
        tpr_start
        exit 0
    ;;

    stop)
        tpr_stop
        exit 0
    ;;

    restart)
        tpr_stop
        tpr_start
        exit 0
    ;;

    *)
        echo "Error: argument '$1' not supported." >&2
        exit 0
    ;;
esac



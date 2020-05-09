#
# Regular cron jobs for the safeboot package
#
0 4	* * *	root	[ -x /usr/bin/safeboot_maintenance ] && /usr/bin/safeboot_maintenance

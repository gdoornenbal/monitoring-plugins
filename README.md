# monitoring-plugins
Here i put some created or modified monitoring plugins voor nagios/opsview/icinga.

###check_snmp_mem

An old but usefull check for cisco, procurve and linux.  As we had also use hpux, i added that one to, instead of using another plugin.

###check_snmp_storage

This one was already for linux and windows. added also hpux.  Same writer had another plugin for that, which was almost the same. so i put them together.

###check_smb_share

This is an old one, which i gave a huge update, so the following checks are now possible:
 * existence of a share.
 * existence of a file or directory on a share. (optional inside a directory.)
 * check that a file or wildcard does NOT exist on a share.
 * check the maximum age of a file in seconds.
 * using a passwordfile for credentials.
 
###check_mysql_query.pl

This is also an old one created once by Michal Sviba, now with a huge update. 
in short the following:
 * code cleanup.
 * added verbose, performance output options.
 * modified default warning/critical behavior. (no defaults anymore)
 * added option to give complete QUERY instead of parts.
 * added options to use an sql file as query.

###check_h3c_components.sh

This one is initaly created by ljorg, but i did a huge update:
 * modified input supporting commandline options with arguments instead of arguments only.
 * added debug option
 * added check for number of expected irf and psu's (thanks to frank. https://github.com/franklouwers/nagios-checks)
 * added failed SFP link check count option.
 
###check_aruba_instant

Used to monitor number of AP's and connected devices in an aruba instant cluster.  You can set filters and warning parameters. See script help for more info.

###check_snmp_win

An old plugin to check the state of windows services (http://nagios.manubulon.com). I expanded the type (-T) option with 'process', so we can check for any process running in windows, even when it is not a service.
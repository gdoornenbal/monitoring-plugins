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

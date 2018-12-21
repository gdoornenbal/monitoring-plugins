# monitoring-plugins
Here i put some created or modified monitoring plugins voor nagios/opsview/icinga.

### check_snmp_mem
An old but usefull check for cisco, procurve and linux.  As we had also use hpux, i added that one to, instead of using another plugin.
### check_snmp_storage
This one was already for linux and windows. added also hpux.  Same writer had another plugin for that, which was almost the same. so i put them together.
### check_smb_share
This is an old one, which i gave a huge update, so the following checks are now possible:
 * existence of a share.
 * existence of a file or directory on a share. (optional inside a directory.)
 * check that a file or wildcard does NOT exist on a share.
 * check the maximum age of a file in seconds.
 * using a passwordfile for credentials.
 
### check_mysql_query.pl
This is also an old one created once by Michal Sviba, now with a huge update. in short the following:
 * code cleanup.
 * added verbose, performance output options.
 * modified default warning/critical behavior. (no defaults anymore)
 * added option to invert warning critical behaviour. (warning when lower instead of higher)
 * added option to give complete QUERY instead of parts.
 * added options to use an sql file as query.
### check_h3c_components.sh
This one is initaly created by ljorg, but i did a huge update:
 * modified input supporting commandline options with arguments instead of arguments only.
 * added debug option
 * added check for number of expected irf and psu's (thanks to frank. https://github.com/franklouwers/nagios-checks)
 * added failed SFP link check count option.
 
### check_aruba_instant
Used to monitor number of AP's and connected devices in an aruba instant cluster.  You can set filters and warning parameters. See script help for more info.
### check_snmp_win
An old plugin to check the state of windows services (http://nagios.manubulon.com). I expanded the type (-T) option with 'process', so we can check for any 
process running in windows, even when it is not a service.
### check_ssl_certificate
Also an old plugin once created by David Alden. I added an option to use SNI servername, and modified some output text to be more consistent.
### check_oracle_instant
This perl nagios plugin allows you to check oracle service (ability to connect to database ) and the health of oracle database (Dictionary Cache Hit Ratio, 
Library Cache Hit Ratio, DB Block Buffer Cache Hit Ratio, Latch Hit Ratio, Disk Sort Ratio, Rollback Segment Waits, Dispatcher Workload) It only uses the 
oracle instant client, it does not need to install complete ORACLE client or compile other perl modules. i added the following options over the years:
 * Option added to skip specific tests.
 * Added Tablespace usage check. Find's the tablespace with the highest percentage used.
 * Corrected help dialog by vdmkenny
 * Made plugin suiteable for oracle 12.2 without SID support
 * Added verbose output option

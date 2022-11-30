#!/bin/bash
# Rewritten by Gerrit Doornenbal
# Based on script from Andrew Singer (https://www.rainsbrook.co.uk/wiki/doku.php/nagios/check_apcpowerstrip)
# 
# note: AP8XXX measurements below 0.5A are squelched to 0A...
#
# v0.1 nov 2019
#    * changed to named options intead of only options 
#    * added new PDU type.
#    * added debug option
#    * added statistics output
#    * output/return codes tuned
#    *
#
# Request:
# This script is tested on the PDU stated in the help section, but should work with
# other types to.  Please let me know if this script works on other models, so i can
# expland this list.  (g.doornenbal AT gmail.com), or 
#
#Originally written Andrew Stringer, 31/10/2013
#Purpose is to test  power usage on smart power strips
#See http://www.oidview.com/mibs/318/PowerNet-MIB.html
 
#OID's of use for multi bank PDU
#.1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.1 <- Multi-Bank Total Load (divide by 10)
#.1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.2 <- Multi-Bank B1 Load (divide by 10)
#.1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.3 <- Multi-Bank B2 Load (divide by 10)
 
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.2.1 <- Multi-Bank B1 Low Load Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.2.2 <- Multi-Bank B2 Low Load Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.2.1 <- Multi-Bank Total Low Load Warning Threshold
 
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.3.1 <- Multi-Bank B1 Near Overload Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.3.2 <- Multi-Bank B2 Near Overload Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.3.1 <- Multi-Bank Total Near Overload Warning Threshold
 
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.4.1 <- Multi-Bank B1 Overload Alarm Threshold
#.1.3.6.1.4.1.318.1.1.12.2.4.1.1.4.2 <- Multi-Bank B2 Overload Alarm Threshold
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.4.1 <- Multi-Bank Total Overload Alarm Threshold 
 
#Single Bank OID
#.1.3.6.1.4.1.318.1.1.12.2.3.1.1.2.1 <- Single-Bank Total Load (divide by 10)
 
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.2.1 <- Single-Bank Low Load Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.3.1 <- Single-Bank Near Overload Warning Threshold
#.1.3.6.1.4.1.318.1.1.12.2.2.1.1.4.1 <- Single-Bank Overload Alarm Threshold
 
#.1.3.6.1.4.1.318.1.1.12.1.5.0 = PDU Model number, dual AP8953, single AP7954
 
PROGNAME=`basename $0`
version="version 0.1"
debug=0

SINGLEBANK="AP7951,AP7954"
DUALBANK="AP7922,AP8953,AP8853"

nagios_status=0
nagios_states=(OK WARNING CRITICAL UNKNOWN)
nagios_message=""
statistics="|" # format: 'label'=value[UOM];[warn];[crit];[min];[max]
stats=0;
BANK=T  #Default total only
squelched="squelched to"

#Print out command line options
usage() { 
	echo "Usage: $PROGNAME -H <hostname> -C <communitystring> "
	echo 
	echo "Plugin to read the power load from network connected APC PDU's."
	echo "This plugin reads the system-name and the Warning/Critical tresholds from the PDU."
	echo "So you should set these settings in the (web)GUI of the PDU."
	echo "There different PDU types, some with multiple internal power distrubition banks."
	echo "This plugin can read these banks separately with the -B (Bank) option as stated below:"
	echo " -B <T/B1/B1/A>"
	echo "    Default = T(otal), option A(ll) gives all Banks + Total."
	echo 
	echo "Other (optional) options:"
	echo " -f  Give also statistic info."
	echo " -V  Version of this plugin."
	echo " -d  Debug, show extra info."
	echo " -h or -? This help message."
	echo
    echo "This plugin should work on many PDU models, but is tested on the following PDU's:"
	echo " AP7951,AP7954,AP7922,AP8953,AP8853"
	exit 1; 
	}

while getopts C:H:B:dhfV? options;
do
	case $options in
		C ) COMMSTRING="$OPTARG";;
		H ) HOSTNAME="$OPTARG";;
		B ) BANK="$OPTARG";;
		d ) debug=1;;
		f ) stats=1;;
		V ) echo "${0##*/} $version"
		exit 1;;
    	? ) usage;;
        h ) usage;;
	esac
done

if [ "$COMMSTRING" == "" ] || [ "$HOSTNAME" == "" ]; then
  usage
fi 
 
SNMPGET=/usr/bin/snmpget
 
MODEL=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.1.5.0 | cut -d: -f4 | cut -d" " -f2 | sed 's/^\"\(.*\)\"$/\1/' `
NAME=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-MIB::sysName.0 | cut -d: -f4 | cut -d" " -f2 | sed 's/^\"\(.*\)\"$/\1/' `

#SNMPv2-MIB::sysName.0
if [ $debug = 1 ]; then echo "Model PDU found is: ${MODEL}  Name:$NAME";echo; fi
nagios_message="${NAME}:"
 
if [ -z "${MODEL}" ]; then
        echo "UNKNOWN - An error has occurred communicating with the PDU."
        exit 3
fi

# First do the total load (is the same for SINGLE and DUAL bank PDU's!
	if [[ "TA" == *"${BANK}"* ]]
	then
        TOTALLOADRAW=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.3.1.1.2.1 | cut -d: -f4 | cut -d" " -f2 `
        TOTALLOAD=`echo "scale = 2; $TOTALLOADRAW / 10" | bc -l`
        WARNINGTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.2.1.1.3.1 | cut -d: -f4 | cut -d" " -f2 `
        CRITICALTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.2.1.1.4.1 | cut -d: -f4 | cut -d" " -f2 `
		TOTALMAXLOAD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.1.3.0 | cut -d: -f4 | cut -d" " -f2 `
		statistics="$statistics 'TOTAL'=$TOTALLOAD;$WARNINGTHRESHOLD;$CRITICALTHRESHOLD;0;$TOTALMAXLOAD"
        if [ $TOTALLOAD == 0 ] && [[ "${MODEL}" == "AP8"* ]]; then TOTALLOAD="$squelched 0"; fi
		
		if [ $debug = 1 ]; then echo "TOTAL load=${TOTALLOAD}A (raw:${TOTALLOADRAW}),  w=${WARNINGTHRESHOLD}, c=${CRITICALTHRESHOLD} "; fi
 
        if [[ "$TOTALLOADRAW" -lt $(($WARNINGTHRESHOLD * 10)) ]]; then
                nagios_message="$nagios_message Total Load:${TOTALLOAD}A."
        elif [[ "$TOTALLOADRAW" -le $(($CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Total Load:${TOTALLOAD}A, warning:${WARNINGTHRESHOLD}A."
                nagios_status=1
        elif [[ "$TOTALLOADRAW" -ge $(($CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Total Load:${TOTALLOAD}A, critical:${CRITICALTHRESHOLD}A."
                nagios_status=2
        else
                nagios_message="$nagios_message Total Load:unknown."
                nagios_status=3
        fi
		
	fi
 
if [[ "$SINGLEBANK" == *"${MODEL}"* ]]
then
        TYPE='SINGLEBANK'
fi

if [[ "$DUALBANK" == *"${MODEL}"* ]]
then
        TYPE='DUALBANK'

		case ${BANK} in
        B1|b1|A)
        #Bank B1 load
        BANK1LOADRAW=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.3.1.1.2.2 | cut -d: -f4 | cut -d" " -f2 `
        BANK1LOAD=`echo "scale = 2; $BANK1LOADRAW / 10" | bc -l`
        B1WARNINGTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.4.1.1.3.1 | cut -d: -f4 | cut -d" " -f2 `
        B1CRITICALTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.4.1.1.4.1 | cut -d: -f4 | cut -d" " -f2 `
		B1MAXLOAD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.1.6.1.3.1 | cut -d: -f4 | cut -d" " -f2 `
		statistics="$statistics 'BANK1'=$BANK1LOAD;$B1WARNINGTHRESHOLD;$B1CRITICALTHRESHOLD;0;$B1MAXLOAD"
		if [ $BANK1LOAD == 0 ] && [[ "${MODEL}" == "AP8"* ]]; then BANK1LOAD="$squelched 0"; fi
		
        if [ $debug = 1 ]; then echo "BANK1 load=${BANK1LOAD}A (raw:${BANK1LOADRAW}), w=${B1WARNINGTHRESHOLD}, c=${B1CRITICALTHRESHOLD} "; fi
        
		
        if [[ "$BANK1LOADRAW" -lt $(($B1WARNINGTHRESHOLD * 10)) ]]; then
                nagios_message="$nagios_message Bank B1 load: ${BANK1LOAD}A."
        elif [[ "$BANK1LOADRAW" -le $(($B1CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Bank B1 load: ${BANK1LOAD}A, warning:${B1WARNINGTHRESHOLD}A."
                nagios_status=1
        elif [[ "$BANK1LOADRAW" -ge $(($B1CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Bank B1 load: ${BANK1LOAD}A, critical:${B1CRITICALTHRESHOLD}A."
                nagios_status=2
        else
                nagios_message="$nagios_message Bank B1 load: unknown."
                nagios_status=3
        fi
        #end of bank B1 case
        ;;&
 
        B2|b2|A)
        #Bank B2 load
        BANK2LOADRAW=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.3.1.1.2.3 | cut -d: -f4 | cut -d" " -f2 `
        BANK2LOAD=`echo "scale = 2; $BANK2LOADRAW / 10" | bc -l`
        B2WARNINGTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.4.1.1.3.2 | cut -d: -f4 | cut -d" " -f2 `
        B2CRITICALTHRESHOLD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.4.1.1.4.2 | cut -d: -f4 | cut -d" " -f2 `
		B2MAXLOAD=`${SNMPGET} -v1 -c ${COMMSTRING} ${HOSTNAME} SNMPv2-SMI::enterprises.318.1.1.12.2.1.6.1.3.2 | cut -d: -f4 | cut -d" " -f2 `
		statistics="$statistics 'BANK2'=$BANK2LOAD;$B2WARNINGTHRESHOLD;$B2CRITICALTHRESHOLD;0;$B2MAXLOAD"
		if [ $BANK2LOAD == 0 ] && [[ "${MODEL}" == "AP8"* ]]; then BANK2LOAD="$squelched 0"; fi
		
        if [ $debug = 1 ]; then echo "BANK2 load=${BANK2LOAD}A (raw:${BANK2LOADRAW}), w=${B2WARNINGTHRESHOLD}, c=${B2CRITICALTHRESHOLD} "; fi
 
        if [[ "$BANK2LOADRAW" -lt $(($B2WARNINGTHRESHOLD * 10)) ]]; then
                nagios_message="$nagios_message Bank B2 load:${BANK2LOAD}A."

        elif [[ "$BANK2LOADRAW" -le $(($B2CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Bank B2 load:${BANK2LOAD}A, warning:${B2WARNINGTHRESHOLD}A."
                nagios_status=1
        elif [[ "$BANK2LOADRAW" -ge $(($B2CRITICALTHRESHOLD * 10 )) ]]; then
                nagios_message="$nagios_message Bank B2 load:${BANK2LOAD}A, critical:${B2CRITICALTHRESHOLD}A."
                nagios_status=2
        else
                nagios_message="$nagios_message Bank B2 load: unknown."
                nagios_status=3
        fi
        #end of bank B2 case
        ;;&
 
        esac
else
        nagios_message="$nagios_message No Match for PDU model ${MODEL} found."
        TYPE='UNKNOWN'
		nagios_status=3
fi

if [ $debug = 1 ]; then echo "PDU type is: ${TYPE}"; fi


if [ $stats = 1 ]; then
	nagios_message="$nagios_message $statistics"
	fi
echo "${nagios_states[$nagios_status]}: $nagios_message"
 
 
exit $nagios_status



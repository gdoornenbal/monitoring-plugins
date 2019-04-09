#!/bin/bash
# bash script to check various components in an HP/H3C S51xx switch
# Can check IRF-connected stacks too.
# lajo@kb.dk / 20120724
#
# Requires net-snmp-utils.
#
# changes by Gerrit Doornenbal:
#  29-09-2016 added option check and usage-info
#  08-03-2017 added IRF/PSU check based on mod by franklouwers
#             https://github.com/franklouwers/nagios-checks
#             added failed SFP module count
#             also added debug option. (i like that :)
#

community=""
hostname=""
checkpsu=0
checkirf=0
checksfp=0
debug=0

usage () {
echo "\
Nagios plugin to check h3c components.

Usage:
     check_h3c_components.sh -H <hostname> -C <community> [-n -i <irfcount> -p <psucount> -s<failed SFP count> -d]  
     -H hostname/IP of the h3c switch.
     -C SNMP community name.
     -s When there are unused SFP modules in the stack, give the number of
        modules without a link. When another one is failing, we got an alert.
     -i Check if there are N active stack/irf members.
     -p Check the expected number of PSU units.
     -d debug, show some extra output of found components.
     -h this help message.
"
}

while getopts C:H:i:p:s:dh? options;
do
	case $options in
		C ) community="$OPTARG";;
		H ) hostname="$OPTARG";;
		i ) checkirf="$OPTARG";;
		p ) checkpsu="$OPTARG";;
		s ) checksfp="$OPTARG";;
		d ) debug=1;;
    	? ) usage
        	exit 1;;
        -h ) usage
            exit 1;;
	esac
done

if [ "$community" == "" ] || [ "$hostname" == "" ]; then
  usage
  exit 1
fi

#if [ $checksfp = 0 ]; then
#  sfpcode=2
#else
#  sfpcode=31
#fi


OID=.1.3.6.1.4.1.25506.2.6.1.1.1.1.19
statustext[1]="Not Supported"
statustext[2]="OK"
statustext[3]="POST Failure"
statustext[11]="PoE Error"
statustext[22]="Stack Port Blocked"
statustext[23]="Stack Port Failed"
statustext[31]="SFP Receive Error"
statustext[32]="SFP Send Error"
statustext[33]="SFP Send and Receive Error"
statustext[41]="Fan Error"
statustext[51]="Power Supply Error"
statustext[61]="RPS Error"
statustext[71]="Module Faulty"
statustext[81]="Sensor Error"
statustext[91]="Hardware Faulty"

# Make the array separate on newlines only.
IFS='
'
component=( $( snmpwalk -v2c -OEqv -c $community $hostname .1.3.6.1.2.1.47.1.1.1.1.2 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi
status=( $( snmpwalk -v2c -OEqv -c $community $hostname .1.3.6.1.4.1.25506.2.6.1.1.1.1.19 2>/dev/null) )
if [ $? -ne 0 ]; then
  echo "UNKNOWN: SNMP timeout"
  exit 3
fi

errors=0
psus=0
sfps=0
msg=''
tmpmsg=''

for (( i = 0 ; i < ${#component[@]} ; i++ )) do
  # show found components in debug, except all working Ethernet ports.. (this is to limit the info a bit...)
  if [ $debug = 1 ] && [[ ${component[$i]} != *"Ethernet"* || ${status[$i]} -ne 2 ]]; then echo ${component[$i]} ${status[$i]}; fi

  # find failed component...
  if [ ${status[$i]} -ne 2 ]; then
	# Test for failed sfp modules check..
	if [[ ${status[$i]} -eq 31 && $checksfp -ne 0 ]]; then
		# Strip out quotes from the component description
		s=${component[$i]}
		tmpmsg="${tmpmsg}${s//\"}: ${statustext[${status[$i]}]} - "
		((sfps++))
	else
		# Strip out quotes from the component description
		s=${component[$i]}
		msg="${msg}${s//\"}: ${statustext[${status[$i]}]} - "
		errors=1
	fi
  fi
  # count found PSU's
  if [[ ${component[$i]} =~ "Power Supply Unit" || ${component[$i]} =~ "PSU" ]]; then
    ((psus++))
  fi
done

# Extra check: find number of irf members in this stack.
if [ $checkirf -ne 0 ]; then
	if [ $debug = 1 ]; then echo "We need $checkirf members in the irf stack."; fi
	status=( $( snmpwalk -v2c -OEqv -c $community $hostname .1.3.6.1.4.1.25506.2.91.1.2.0  2>/dev/null) )
	if [ $? -ne 0 ]; then
	  echo "UNKNOWN: SNMP timeout"
	  exit 3
	fi
	if [ $debug = 1 ]; then echo "We have $status members in the irf stack."; fi
	if [ $status -ne $checkirf ]; then
	   msg="${msg}IRF members: found $status of $checkirf - "
	   errors=1
	fi
fi

## Extra check: we need $checkpsu power supplies
if [ $checkpsu -ne 0 ]; then
	if [ $debug = 1 ]; then echo "We need $checkpsu Power Supply's in this stack."; fi
	if [ $psus -ne $checkpsu ]; then
	  msg="${msg}PSUs: found $psus of $checkpsu - "
	  errors=1
	fi
fi
if [ $debug = 1 ]; then echo "We have $psus Power Supply's in this stack."; fi

## Extra check: we need $checksfp failing SFP modules
if [ $checksfp -ne 0 ]; then
	if [ $debug = 1 ]; then echo "We need $checksfp failing SFP modules in this stack."; fi
	if [ $sfps -ne $checksfp ]; then
	  msg="${msg}SFPs: found $sfps of $checksfp - ${tmpmsg}"
	  errors=1
	fi
if [ $debug = 1 ]; then echo "We have $sfps failing SFP modules in this stack."; fi
fi

# Create exit status and message.
if [ $errors -gt 0 ]; then
  msg=`echo $msg | sed 's/- $//'`
  echo "CRITICAL: $msg"
  exit 2
else
  echo "All components OK"
  exit 0
fi

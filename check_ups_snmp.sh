#!/bin/bash

# plugin creado por Daniel Dueñas
# Plugin para chequeo a traves de snmp de la tarjeta cs121 y otras tarjetas para ups

# plugin developed by Daniel Dueñas
# modified by Gerrit Doornenbal
# This plugin can check a sai with cs121 and other adapters by snmp.

#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

######       CHANGE LOG        #########
# V1.1:Include new function to measure used output power (by dooger april 2019)
# V1.0:Include new parameter to select de version of snmp (1 or 2c)
# V0.2:Fix the UNKNOWN state when warning value configured was the same as the current temperature on the UPS 
#      thanks to puckel

PROGNAME=`basename $0`
VERSION="Version 1.1"
AUTHOR="2013, Daniel Dueñas Domingo (mail:dduenasd@gmail.com)"
AUTHOR="2019, Daniel Dueñas Domingo, Gerrit Doornenbal"

print_version() {
    echo "$VERSION, $AUTHOR"
}

print_use(){
   echo Use:
   echo "./$PROGNAME -H <ip_address> -p <option>"
   echo ""
   echo "write './$PROGNAME --help' for help"
   exit $ST_UK
}

print_help(){
    print_version $PROGNAME $VERSION
    echo ""
    echo "Description:"
    echo "$PROGNAME is a Nagios plugin to check by snmp a sai or ups status with CS121 and other snmp card adapters."
	echo "With performance data"
    echo ""
    echo "Use:"
    echo "./$PROGNAME -H <ip_address> -p <option>"
    echo ""
	echo "Example:"
	echo "./$PROGNAME -H 10.40.80.1 -p battery_temp -w 25 -c 40"
	echo ""
	echo "OPTIONS:"
    echo "-H|--hostname)"
    echo "   Sets the hostname. Default is: localhost"
	echo "-C|--community)"
	echo "   Sets the snmp read community ('public' by default)"
	echo "-v|--snmpversion 1|2c)"
	echo "   specifies SNMP version to use (2c by default)"
	echo "-p|--parameter)"
	echo "   Sets the parameter you want monitorize (see available parameters below)"
	echo "-h|--help)"
	echo "   Show help"
	echo "-c|--critical"
	echo "   critical value"
	echo "-w|--warning"
	echo "   warning value"
	echo "-d|--dir"
	echo "   mibs files directory ('./mibs' by default)"
	echo "-b|--verbose"
	echo "   Extra output for testing purpose"
	echo "PARAMETERS:"
	echo "ups_alarm:The present number of active alarm conditions. If number is zero, status is OK, if > 0 the status is CRITICAL"
	echo "          If an alarm is present, the plugin show the upsAlarmDescr and upsAlarmTime, if you want show the text description of"
	echo "          the oid upsAlarmDescr, you must define the directory of the mibs files with -d Option (./mibs by default)"
	echo "battery_temp :The ambient temperature at or near the UPS Battery casing."
	echo "             warning and critical values requiered"
	echo "output_load :The percentage of the UPS power capacity presently being used on this output line," 
	echo "             i.e., the greater of the percent load of true power capacity and the percent load of VA."
	echo "             warning and critical required."
	echo "output_power :The UPS power output in Watts currently delivered on this output line."
	echo "              warning and critical are optional."
	echo "output_amp :The UPS power output in ampere's currently delivered on this output line."
	echo "input_voltage :The magnitude of the present input voltage in the input lines."
	echo "             normal value, interval warning and interval critical requiered"
	echo "             Example: normal value is 400V, warning in 395-405 V interval and critical 390-410 V interval"  
	echo "             use: ./$PROGNAME -H 10.40.80.1 -p input_voltage -w 395:405 -c 390:400"
	echo "             in the example, normal value is 400V, warning in 395-405 V interval and critical 390-410 V interval"  
	echo "num_input_lines :The number of input lines utilized in this device. This variable indicates the"
    echo "             number of rows in the input table, percent warning and critical no requiered."
	echo "num_output_lines :The number of output lines utilized in this device. This variable indicates the"
    echo "             number of rows in the output table, warning and critical no requiered."
	echo "battery_status :The indication of the capacity remaining in the UPS system's batteries."  	
	echo "             A value of batteryNormal indicates that the remaining run-time is greater than upsConfigLowBattTime."  
	echo "             A value of batteryLow indicates that the remaining battery run-time is less than or"
	echo "             equal to upsConfigLowBattTime.  A value of batteryDepleted indicates that the UPS will be unable"
	echo "             to sustain the present load when and if the utility power is lost (including the possibility that the"
	echo "             utility power is currently absent and the UPS is unable to sustain the output).warning and critical no requiered. "
	echo "             No perfdata show."
	echo "battery_charge_remain: An estimate of the battery charge remaining expressed as a percent of full charge and minutes."
	echo "             Warning and critical required and refered to the percent of charge"
	echo ""
	
    exit $ST_UK
}

ST_OK=0
ST_WR=1
ST_CR=2
ST_UK=3

host='localhost'
community='public'
parameter='none'
output=''
perfdata=''
state=$ST_OK
statestring=''
val=''
mibsPath="./mibs"
snmpversion='2c'
warning=0
critical=0
verbose=0

#ups oids snmp
oid_upsOutputNumLines='1.3.6.1.2.1.33.1.4.3.0'
oid_upsInputNumLines='1.3.6.1.2.1.33.1.3.2.0'
oid_upsBatteryTemperature='1.3.6.1.2.1.33.1.2.7.0'
oid_upsOutputVoltage='1.3.6.1.2.1.33.1.4.4.1.2' #RMS Volts
oid_upsOutputAmpere='1.3.6.1.2.1.33.1.4.4.1.3' #RMS Amp
oid_upsOutputPower='1.3.6.1.2.1.33.1.4.4.1.4' #RMS Watts
oid_upsOutputPercentLoad='1.3.6.1.2.1.33.1.4.4.1.5' #percent
oid_upsBatteryStatus='1.3.6.1.2.1.33.1.2.1.0'
oid_upsInputVoltage='1.3.6.1.2.1.33.1.3.3.1.3'
oid_upsEstimatedChargeRemaining='1.3.6.1.2.1.33.1.2.4.0'
oid_upsEstimatedMinutesRemaining='1.3.6.1.2.1.33.1.2.3.0'
oid_upsAlarmsPresent='1.3.6.1.2.1.33.1.6.1.0'
oid_upsAlarmDescr='1.3.6.1.2.1.33.1.6.2.1.2'
oid_upsAlarmTime='1.3.6.1.2.1.33.1.6.2.1.3'


num_input_lines(){
	val=`getsnmp $1`
	f_error $?
	output="number of input lines = $val"
	perfdata="'lines'=$val"
}

num_output_lines(){
	val=`getsnmp $1`
	f_error $?
	output="number of output lines = $val"
	perfdata="'lines'=$val"
}

alarm(){
	val=`getsnmp $1`
	f_error $?
	alarmtext=""
	if test $val -eq 0
	   then state=$ST_OK
	   output="no alarms present"
	elif test $val -gt 0
	   counter=1
	   then state=$ST_CR
	   while test $counter -le $val
	      do
          oid1="$2.$counter"
		  oid2="$3.$counter"
		  oidalarmdesc=`getsnmp $oid1`
		  alarmdesc=`snmptranslate -M $4 -m ALL $oidalarmdesc|awk -F:: '{print $2}'`
		  if test "$alarmdesc" = ""
		     then alarmdesc=$oidalarmdesc
		  fi
		  alarmtime=`getsnmp $oid2`
	      alarmtext=$alarmtext" Alarm"$val":"$alarmdesc" "$alarmtime		  
	      counter=`expr $counter + 1`
      done
    else
	   state=$ST_UK
	fi
	output="$val alarms present "$alarmtext
	perfdata="'alarms'=$val"	  
}

temperature(){	
	val=`getsnmp $1`
    f_error $?
	output="battery temperature = "$val"°C"
	perfdata="'temperature'=$val;$2;$3"
	if test $val -gt $3
		then state=$ST_CR
	elif test $val -ge $2
		then state=$ST_WR
	elif test $val -lt $2 
		then state=$ST_OK
	else 
		state=$ST_UK
	fi
}

output_load(){
   numlines=`getsnmp $4`
   if test $numlines -le 0
      then echo "error number of lines=$numlines"
	       exit $ST_UK
   fi
   counter=1
   while test $counter -le $numlines
   do
      oid="$1.$counter"
	  if test $verbose -eq 1 ; then echo "command: snmpget -v $snmpversion -c $community $host $oid"; fi
	  percentload[$counter]=`getsnmp $oid`
	  counter=`expr $counter + 1`
   done
   output="Percent Load of $numlines lines:"
   perfdata=""
   counter=1
   flag=0
   for valor in ${percentload[*]}
	  do
	  if test ${percentload[$counter]} -gt $3
	     then state=$ST_CR
		      flag=3
	  elif test ${percentload[$counter]} -gt $2
	     then if test $flag -le 2 
		         then state=$ST_WR
				 flag=2
		      fi
	  elif test ${percentload[$counter]} -le $2
	     then if test $flag -le 0
			     then state=$ST_OK
		      fi
	  else
	     if test $flag -le 1
	        then state=$ST_UK
			flag=1
		 fi
	  fi
	  output=$output" L$counter=${percentload[$counter]}%"
	  perfdata=$perfdata"'L$counter'=${percentload[$counter]}%;$2;$3;0;100 "
      counter=`expr $counter + 1`
   done   
}

output_power(){
   numlines=`getsnmp $4`
   if test $numlines -le 0
      then echo "error number of lines=$numlines"
	       exit $ST_UK
   fi
   counter=1
   while test $counter -le $numlines
   do
      oid="$1.$counter"
	  if test $verbose -eq 1 ; then echo "command: snmpget -v $snmpversion -c $community $host $oid"; fi
	  powerload[$counter]=`getsnmp $oid`
	  counter=`expr $counter + 1`
   done
   output="Power load of $numlines lines:"
   perfdata=""
   counter=1
   flag=0
   for valor in ${powerload[*]}
	  do
	  if test $2 -ne 0 && test $3 -ne 0
		then if test ${powerload[$counter]} -gt $3
			then state=$ST_CR
				flag=3
		elif test ${powerload[$counter]} -gt $2
			then if test $flag -le 2 
					then state=$ST_WR
					flag=2
				fi
		elif test ${powerload[$counter]} -le $2
			then if test $flag -le 0
					then state=$ST_OK
				fi
		else
			if test $flag -le 1
			then state=$ST_UK
				flag=1
			fi
		fi
	  fi
	  output=$output" L$counter=${powerload[$counter]}W"
	  perfdata=$perfdata"'L$counter'=${powerload[$counter]}W;$2;$3;0 "
      counter=`expr $counter + 1`
   done   
}

output_amp(){
   numlines=`getsnmp $4`
   if test $numlines -le 0
      then echo "error number of lines=$numlines"
	       exit $ST_UK
   fi
   counter=1
   while test $counter -le $numlines
   do
      oid="$1.$counter"
	  if test $verbose -eq 1 ; then echo "command: snmpget -v $snmpversion -c $community $host $oid"; fi
	  deciamp=`getsnmp $oid`
	  poweramp[$counter]=$(bc <<< "scale=1; $deciamp/10")
	  counter=`expr $counter + 1`
   done
   output="Current flow of $numlines lines:"
   perfdata=""
   counter=1
   flag=0
   for valor in ${poweramp[*]}
	  do
	  if test $2 -ne 0 && test $3 -ne 0
	    amp=${poweramp[$counter]}
		 then if (( $(echo "$amp > $3" | bc -l ) ))
			then state=$ST_CR
				flag=3
		elif (( $(echo "$amp > $2"|bc -l ) ))
			then if test $flag -le 2 
					then state=$ST_WR
					flag=2
				fi
		elif (( $(echo "$amp <= $2"|bc -l ) ))
			then if test $flag -le 0
					then state=$ST_OK
				fi
		else
			if test $flag -le 1
			then state=$ST_UK
				flag=1
			fi
		fi
	  fi
	  output=$output" L$counter=${poweramp[$counter]}A"
	  perfdata=$perfdata"'L$counter'=${poweramp[$counter]}A;$2;$3;0 "
      counter=`expr $counter + 1`
   done   
}

input_voltage(){
   numlines=`getsnmp $4`
   f_error $?
   if test $numlines -le 0
      then echo "error number of lines=$numlines"
	       exit $ST_UK
   fi
   counter=1
   while test $counter -le $numlines
   do
      oid="$1.$counter"
	  voltage[$counter]=`getsnmp $oid`
	  f_error $?
	  counter=`expr $counter + 1`
   done
   output="Voltage of $numlines input lines:"
   perfdata=""
   counter=1
   flag=0
   warningup=`echo $2 | awk -F: '{print $2}'`
   warningdown=`echo $2 | awk -F: '{print $1}'`
   criticalup=`echo $3 | awk -F: '{print $2}'`
   criticaldown=`echo $3 | awk -F: '{print $1}'`
   for valor in ${voltage[*]}
	  do
	  if test ${voltage[$counter]} -gt $criticalup
	     then state=$ST_CR
		      flag=3
	  elif test ${voltage[$counter]} -lt $criticaldown
	     then state=$ST_CR
		      flag=3
	  elif test ${voltage[$counter]} -gt $warningup
	     then if test $flag -le 2 
		         then state=$ST_WR
				 flag=2
		      fi
	  elif test ${voltage[$counter]} -lt $warningdown
	     then if test $flag -le 2 
		         then state=$ST_WR
				 flag=2
		      fi
	  elif test ${voltage[$counter]} -le $warningup
	     then if test $flag -le 0
			     then state=$ST_OK
		      fi
	  else
	     if test $flag -le 1
	        then state=$ST_UK
			flag=1
		 fi
	  fi
	  output=$output" L$counter=${voltage[$counter]}V"
	  perfdata=$perfdata"'L$counter'=${voltage[$counter]};$2;$3;; "
      counter=`expr $counter + 1`
   done   
}

battery_status(){
	val=`getsnmp $1`
	f_error $?
	case $val in
	   1)battery_status="unknown"
	     state=$ST_UK
		 ;;
	   2)battery_status="Normal"
	     state=$ST_OK
		 ;;
	   3)battery_status="Low"
	     state=$ST_WR
		 ;;
       4)battery_status="Depleted"
	     state=$ST_CR
		 ;;
	esac
	output="battery status = "$battery_status
}

battery_charge_remain(){	
	percent=`getsnmp $1`
	val=`getsnmp $2`
	valinsecs=`expr $val \* 60`
    f_error $?
	output="estimated battery charge: $percent%, estimated minutes to depleted: $val min "
	perfdata="'charge'="$percent"%;$3;$4;; 'time_to_depleted'="$valinsecs"s;;;0;"
	if test $percent -le $4
		then state=$ST_CR
	elif test $percent -le $3
		then state=$ST_WR
	elif test $percent -gt $3 
		then state=$ST_OK
	else 
		state=$ST_UK
	fi
}


#obtain the value of the oid
getsnmp(){
	#echo "snmpget -v $snmpversion -c $community $host $1"
	text=`snmpget -v $snmpversion -c $community $host $1`
	if [ $? -ne 0 ] 
	  then 
		echo "plugin $PROGNAME failure, snmpget command error"
		echo $text
		exit $ST_UK
	fi
	echo $text | awk '{print $4}'
	
} 

#test error in the exit of function
f_error(){
    if [ $1 -ne 0 ]
		then
		echo $val
		exit $ST_UK
	fi
}

if test $# -eq 0
	then print_use
fi

while test -n "$1"; do
   case "$1" in
    
		--help|-h) 
			print_help
			;;
		--host|-H) 
			host=$2
			shift
			;;
		--community|-C)
		    community=$2
			shift
			;;
		--snmpversion|-v)
			snmpversion=$2
			shift
			;;
		--parameter|-p) 
			parameter=$2
			shift
			;;
		--warning|-w)
			warning=$2
			shift
			;;
		--critical|-c)
			critical=$2
			shift
			;;
		--dir|-d)
		    mibsPath=$2
			shift
			;;
		--verbose|-t)
		    verbose=1
			;;
        *) 
			echo "Unknown argument: $1"
			print_use
			;;
		
    esac
	shift
done

#read snmp parameter
case $parameter in
   ups_alarm)
	    alarm $oid_upsAlarmsPresent $oid_upsAlarmDescr $oid_upsAlarmTime $mibsPath
		;;
   battery_temp) 
        temperature $oid_upsBatteryTemperature $warning $critical
        ;;
   output_load)
        output_load $oid_upsOutputPercentLoad $warning $critical $oid_upsOutputNumLines
		;;
   output_power)
        output_power $oid_upsOutputPower $warning $critical $oid_upsOutputNumLines
		;;
   output_amp)
        output_amp $oid_upsOutputAmpere $warning $critical $oid_upsOutputNumLines
		;;
	input_voltage)
        input_voltage $oid_upsInputVoltage $warning $critical $oid_upsInputNumLines
		;;
   num_input_lines)
		num_input_lines $oid_upsInputNumLines
		;;
   num_output_lines)
		num_output_lines $oid_upsOutputNumLines
		;;
   battery_status)
		battery_status $oid_upsBatteryStatus
		;;
   battery_charge_remain)
        battery_charge_remain $oid_upsEstimatedChargeRemaining $oid_upsEstimatedMinutesRemaining $warning $critical
		;;
   *)
		echo Unknown option:$1
		print_help
        ;;
esac

#state string set
if test $state -eq $ST_OK
	then statestring="OK"
elif test $state -eq $ST_WR
	then statestring="WARNING"
elif test $state -eq $ST_CR
	then statestring="CRITICAL"
elif test $state -eq $ST_UK
	then statestring="UNKNOWN"
fi

echo "$statestring - $output|$perfdata"
exit $state

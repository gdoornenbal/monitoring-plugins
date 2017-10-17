#!/usr/bin/perl
#####################################################################
#
# check_mysql_query.pl
#  jan 2017 Gerrit Doornenbal
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# feb 2017 by Gerrit Doornenbal
#   Huge rewrite, several debugging and other options added.
#   added SQL option, with file and direct SQL.
# okt 2017
#   Added option to add status based on sql output value.
#
# This script is based on:
#   check_mysql_count.pl version 0.02
#   2008-2011 Michal Sviba
#   contact the author directly for more information at:
#   michal at myserver.cz
#
#####################################################################
#
# Check output of a sql query.  The output header is used as name for the output.
# This plugin requires that mysql is installed on the system.
#

use strict;
use Getopt::Long;

#sub print_usage;

my $TIMEOUT = 15;
my $MYSQL = "mysql";
my %ERRORS = ('UNKNOWN' , '-1',
              'OK' , '0',
              'WARNING', '1',
              'CRITICAL', '2');
my $state = "OK";
my $count = 0;
my $countname = "";
my $status;

my $host="localhost";
my $port=3306;
my $user;
my $pass;
my ($DB, $TABLE, $COND, $QUERY, $SQL);
my ($warn, $crit, $invert);
my ($perf, $debug);

#Start 
check_options();

if (defined($debug)) { print ("\n");} #extra space above debug output
#Create the correct SQL query
if (defined($QUERY)) {
	#test for sql file or direct query
	if (index($QUERY, ".sql") != -1) {
		$SQL = "source $QUERY;";	
		if (defined($debug)) { 
			print "SQL script file: $QUERY\n"; 
			print "SCRIPT:\n"; 
			open FILE, "$QUERY" or die "Could not open $QUERY";
				while(<FILE>) {
				print " $_";
				}
			close FILE;
			print "\n"; 
			}
	} else { 
		$SQL = "$QUERY;";
		if (defined($debug)) { 
			print "SCRIPT:\n";
			print (" $SQL\n");
			}
	}
} else { 
	$COND =~ s/'/\\'/g;
	if ($COND ne "") {$COND = "WHERE $COND";}
	$SQL = "SELECT COUNT(1) \"rows\" FROM $TABLE $COND;";
}

#if (defined($debug)) { print ("SQL query: $SQL \n");}

#Start the query
open (OUTPUT, "$MYSQL -B -h $host -u $user --password=\"$pass\" $DB -e '$SQL' 2>&1 |");
#And read the SQL output.
while (<OUTPUT>) {
	if (/failed/||/ERROR/) { 
		#set state and statustext when error occurs
		$state="CRITICAL"; 
		$status="$state: $_"; 
		last; 
		}
	chomp;
	if ($countname eq "") { #first field = name, second = value
		$countname = $_
		} else { 
		$count = $_;
		}
}
if (defined($debug)) { print "SQL RESULT: name=$countname count=$count\n"; }

#Check for warn/crit criteria
if (defined($warn) && defined($crit) ) {
	if (defined($invert)) {
		if (defined($debug)) { print "Give error when count value ($count) is lower than w/c limits ($warn/$crit)\n"; }
		if ($count <= $warn) { $state = "WARNING"; }
		if ($count <= $crit) { $state = "CRITICAL"; }
	} else {
		if (defined($debug)) { print "Give error when count value ($count) is higher than w/c limits ($warn/$crit)\n"; }
		if ($count >= $warn) { $state = "WARNING"; }
		if ($count >= $crit) { $state = "CRITICAL"; }
	}
}
if ($count =~ m/\D/) { $state = "UNKNOWN"; }
#Create correct output, including perfdata.
if ( not defined($status) ){ 
	if ( defined($TABLE) ){ 
		$TABLE="in table $TABLE";
	} else { 
		$TABLE="found";
	}
	$status = "$state: $count $countname $TABLE"; 
	if ( defined($perf) ) {
		$status = "$status|'$countname'=$count;$warn;$crit;0;"
	}
}

print "$status\n";
exit $ERRORS{$state};

sub check_options () {
	if ( $ARGV[0] eq '')
		{  
		print "Required arguments not given!\n\n";
		print_usage() 
		}

	my $o_help;
	my $o_debug;

	Getopt::Long::Configure ("bundling");
	GetOptions(
		'h|help'	=> \$o_help,
		'v|verbose'	=> \$debug,
		'H|hostname:s'	=> \$host,
		'P|port:i'	=> \$port,
		'u|user:s'	=> \$user,
		'p|pass:s' => \$pass,
		'D|database:s' => \$DB,
		'T|table:s' => \$TABLE,
		'C|cond:s' => \$COND,
		'Q|query:s' => \$QUERY,
		'w|warn:i' => \$warn,
		'c|crit:i'	=> \$crit,
		'i|invert'	=> \$invert,
		'f|perf'	=> \$perf,
	);

	print_usage() if (defined($o_help));
	$debug = 1 if (defined($o_debug));
}

sub print_usage {
	print "MySQL plugin for Nagios, version 0.2; 2008-2011 Michal Sviba; 2017 Gerrit Doornenbal\n\n";
	print "Script for running a SQL script @ MySQL.  The result of the SQL script should contain two lines with each one value:\n";
	print "   line 1: the name for the value, line 2: the value.\n\n";
	print "Usage: check_mysql_query.pl -H <host> -u <user> -p <pass> -D <db> -T <table> -C <cond> -Q <SQL query or file> [-w <warn> -c <crit> -f -v] \n";
	print "   -u username to login to mysql at <host>\n";
	print "   -p password with SELECT privilege to use for <user> at <host>\n";
	print "   -D DB where table is placed \n";
	print "    -T table in DB\n";
	print "    -C conditionals in where section. (without 'where')\n";
	print "   or\n";
	print "    -Q Instead of table and conditionals you can also give a SQL query or a .sql filename with the query.\n";
	print "       This gives you the opportunity to use more complicated scripts.\n";
	print "   -w output value (number of rows) warning state.\n";
	print "   -c output vale (number of rows) to critical state.\n";
	print "   -i invert warning/critical checks: check output value is lower instead of higher(default).\n";
	print "      example: w=10, c=5: output 15=>OK, output 9=>warning, output 5=>critical\n";
	print "   -f Show performance output.\n";
	print "   -v Verbose output, nice for testing your scripts.\n";
	print "Examples:\n";
	print "   check_mysql_query.pl -H hostname -u user -p yourpass -D mysql -T user -w 10 -c 20\n";
	print "      this one counts the number of rows in the mysql user table, and gives warning >10 rows, critical >20 rows.\n";
	print "   check_mysql_query.pl -H hostname -u user -p yourpass -D mysql -Q 'SELECT COUNT(1) \"rows\" FROM user' -f\n";
	print "      counts the number of rows in the mysql user table, gives also performance output.\n";
	print "   check_mysql_query.pl -H hostname -u user -p yourpass -D mysql -Q script.sql -f\n";
	print "      Execute the script inside script.sql on database mysql, with performance output.\n";
	exit $ERRORS{"UNKNOWN"};
}
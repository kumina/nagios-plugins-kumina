#!/usr/bin/perl -w

# check_megaraid_sas Nagios plugin
# Copyright (C) 2007  Jonathan Delgado, delgado@molbio.mgh.harvard.edu
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 
# 
# Nagios plugin to monitor the status of volumes attached to a LSI Megaraid SAS 
# controller, such as the Dell PERC5/i and PERC5/e. If you have any hotspares 
# attached to the controller, you can specify the number you should expect to 
# find with the '-s' flag.
#
# The paths for the Nagios plugins lib and MegaCli may need to me changed.
#
# Code for correct RAID level reporting contributed by Frode Nordahl, 2009/01/12.
#
# $Author: delgado $
# $Revision: #12 $ $Date: 2010/10/18 $

use strict;
use Getopt::Std;
use lib qw(/usr/lib/nagios/plugins /usr/lib64/nagios/plugins); # possible pathes to your Nagios plugins and utils.pm
use utils qw(%ERRORS);

our($opt_h, $opt_s, $opt_o, $opt_m, $opt_p);


getopts('hs:o:p:m:');

if ( $opt_h ) {
	print "Usage: $0 [-s number] [-m number] [-o number]\n";
	print "       -s is how many hotspares are attached to the controller\n";
	print "       -m is the number of media errors to ignore\n";
	print "       -p is the predictive error count to ignore\n";
	print "       -o is the number of other disk errors to ignore\n";
	exit;
}

my $megaclibin = '/usr/sbin/MegaCli';  # the full path to your MegaCli binary
my $megacli = "sudo $megaclibin";      # how we actually call MegaCli
my $megapostopt = '-NoLog';            # additional options to call at the end of MegaCli arguments

my ($adapters);
my $hotspares = 0;
my $hotsparecount = 0;
my $pdbad = 0;
my $pdcount = 0;
my $mediaerrors = 0;
my $mediaallow = 0;
my $prederrors = 0;
my $predallow = 0;
my $othererrors = 0;
my $otherallow = 0;
my $result = '';
my $status = 'OK';

sub max_state ($$) {
	my ($current, $compare) = @_;
	
	if (($compare eq 'CRITICAL') || ($current eq 'CRITICAL')) {
		return 'CRITICAL';
	} elsif ($compare eq 'OK') {
		return $current;
	} elsif ($compare eq 'WARNING') {
		return 'WARNING';
	} elsif (($compare eq 'UNKNOWN') && ($current eq 'OK')) {
		return 'UNKNOWN';
	} else {
		return $current;
	}
}

sub exitreport ($$) {
	my ($status, $message) = @_;
	
	print STDOUT "$status: $message\n";
	exit $ERRORS{$status};
}


if ( $opt_s ) {
	$hotspares = $opt_s;
}
if ( $opt_m ) {
	$mediaallow = $opt_m;
}
if ( $opt_p ) {
	$predallow = $opt_p;
}
if ( $opt_o ) {
	$otherallow = $opt_o;
}

# Some sanity checks that you actually have something where you think MegaCli is
(-e $megaclibin)
	|| exitreport('UNKNOWN',"error: $megaclibin does not exist");	

# Get the number of RAID controllers we have
open (ADPCOUNT, "$megacli -adpCount $megapostopt |")  
	|| exitreport('UNKNOWN',"error: Could not execute $megacli -adpCount $megapostopt");

while (<ADPCOUNT>) {
	if ( m/Controller Count:\s*(\d+)/ ) {
		$adapters = $1;
		last;
	}
}
close ADPCOUNT;

ADAPTER: for ( my $adp = 0; $adp < $adapters; $adp++ ) {
	# Get the number of logical drives on this adapter
	open (LDGETNUM, "$megacli -LDInfo -Lall -a$adp $megapostopt |") 
		|| exitreport('UNKNOWN', "error: Could not execute $megacli -LDInfo -Lall -a$adp $megapostopt");
	
        my @ldlist;

	while (<LDGETNUM>) {
                if ( m/^Virtual Drive:\s+(\d+)/i ) {
                        push (@ldlist, $1);
		}
	}
	close LDGETNUM;
	
	LDISK: foreach my $ld (@ldlist) {
		# Get info on this particular logical drive
		open (LDINFO, "$megacli -LdInfo -L$ld -a$adp $megapostopt |") 
			|| exitreport('UNKNOWN', "error: Could not execute $megacli -LdInfo -L$ld -a$adp $megapostopt ");
			
		my ($size, $unit, $raidlevel, $ldpdcount, $state, $spandepth);
		while (<LDINFO>) {
			if ( m/^Size\s*:\s*((\d+\.?\d*)\s*(MB|GB|TB))/ ) {
				$size = $2;
				$unit = $3;
				# Adjust MB to GB if that's what we got
				if ( $unit eq 'MB' ) {
					$size = sprintf( "%.0f", ($size / 1024) );
					$unit= 'GB';
				}
			} elsif ( m/State\s*:\s*(\w+)/ ) {
				$state = $1;
				if ( $state ne 'Optimal' ) {
					$status = 'CRITICAL';
				}
			} elsif ( m/Number Of Drives\s*(per span\s*)?:\s*(\d+)/ ) {
				$ldpdcount = $2;
			} elsif ( m/Span Depth\s*:\s*(\d+)/ ) {
				$spandepth = $1;
			} elsif ( m/RAID Level\s*: Primary-(\d)/ ) {
				$raidlevel = $1;
			}
		}
		close LDINFO;

		# Report correct RAID-level and number of drives in case of Span configurations
		if ($ldpdcount && $spandepth > 1) {
			$ldpdcount = $ldpdcount * $spandepth;
			if ($raidlevel < 10) {
				$raidlevel = $raidlevel . "0";
			}
		}
		
		$result .= "$adp:$ld:RAID-$raidlevel:$ldpdcount drives:$size$unit:$state ";
		
	} #LDISK
	close LDINFO;
	
	# Get info on physical disks for this adapter
	open (PDLIST, "$megacli -PdList  -a$adp $megapostopt |") 
		|| exitreport('UNKNOWN', "error: Could not execute $megacli -PdList -a$adp $megapostopt ");
	
	my ($slotnumber,$fwstate);
	PDISKS: while (<PDLIST>) {
		if ( m/Slot Number\s*:\s*(\d+)/ ) {
			$slotnumber = $1;
			$pdcount++;
		} elsif ( m/(\w+) Error Count\s*:\s*(\d+)/ ) {
			if ( $1 eq 'Media') {
				$mediaerrors += $2;
			} else {
				$othererrors += $2;
			}
		} elsif ( m/Predictive Failure Count\s*:\s*(\d+)/ ) {
			$prederrors += $1;
		} elsif ( m/Firmware state\s*:\s*(\w+)/ ) {
			$fwstate = $1;
			if ( $fwstate eq 'Hotspare' ) {
				$hotsparecount++;
			} elsif ( $fwstate eq 'Online' ) {
				# Do nothing
			} elsif ( $fwstate eq 'Unconfigured' ) {
				# A drive not in anything, or a non drive device
				$pdcount--;
			} elsif ( $slotnumber != 255 ) {
				$pdbad++;
				$status = 'CRITICAL';
			}
		}
	} #PDISKS
	close PDLIST;
}

$result .= "Drives:$pdcount ";

# Any bad disks?
if ( $pdbad ) {
	$result .= "$pdbad Bad Drives ";
}

my $errorcount = $mediaerrors + $prederrors + $othererrors;
# Were there any errors?
if ( $errorcount ) {
	$result .= "($errorcount Errors) ";
	if ( ( $mediaerrors > $mediaallow ) || 
	     ( $prederrors > $predallow )   || 
	     ( $othererrors > $otherallow ) ) {
		$status = max_state($status, 'WARNING');
	}
}

# Do we have as many hotspares as expected (if any)
if ( $hotspares ) {
	if ( $hotsparecount < $hotspares ) {
		$status = max_state($status, 'WARNING');
		$result .= "Hotspare(s):$hotsparecount (of $hotspares)";
	} else {
		$result .= "Hotspare(s):$hotsparecount";
	}
}

exitreport($status, $result);

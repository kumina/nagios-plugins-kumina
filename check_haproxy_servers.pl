#!/usr/bin/perl -w
#
# Copyright (c) 2010 Stéphane Urbanovski <stephane.urbanovski@ac-nancy-metz.fr>
# Brutal choppage and hackage by liam@kumina.nl
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# you should have received a copy of the GNU General Public License
# along with this program (or with Nagios);  if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA
#
# $Id: $

use strict;					# should never be differently :-)
use warnings;

use Locale::gettext;
use File::Basename;			# get basename()

use POSIX qw(setlocale);
use Time::HiRes qw(time);	# get microtime
use POSIX qw(mktime);

use IO::Socket;				# To use unix Sockets
use Getopt::Long;

use Data::Dumper;

my $PROGNAME = basename($0);
'$Revision: 1.0 $' =~ /^.*(\d+\.\d+) \$$/;  # Use The Revision from RCS/CVS/SVN
my $VERSION = $1;

# i18n :
setlocale(LC_MESSAGES, '');
textdomain('nagios-plugins-perl');

my $DEBUG = 0;
$DEBUG = "";
my $url = "/var/run/haproxy.sock";
my $verbose = "";
my $ignores = "";
GetOptions (	"debug=i" => \$DEBUG,
		"socket=s"   => \$url,
		"verbose" => \$verbose,
		"ignores=s" => \$ignores)
		or die("Error in command line arguments\n");

my @ignoreservers = split(',', $ignores);
my @criticals;
my @warnings;

# For csv data
my $stats="";

my $timer = time();

if ( $url =~ /^\// ) {
	my $sock = new IO::Socket::UNIX (
		Peer => "$url",
		Type => SOCK_STREAM,
		Timeout => 1);
	if ( !$sock ) {
		print "Can't connect to unix socket";
		exit 3;
	}else{
		print $sock "show stat\n";
		while(my $line = <$sock>){
			$stats.=$line;
		}
	}
}else {
	print "Can't detect socket type";
	exit 3;
}
$timer = time()-$timer;

my $message = 'msg';

if ( $stats ne "") {

	if ($DEBUG) {
		print "------------------===csv output===------------------\n$stats\n-----------------------------------------------------\n";
		print "t=".$timer."s\n";
	};

	my @fields = ();
	my @rows = split(/\n/,$stats);
	if ( $rows[0] =~ /#\ \w+/ ) {
		$rows[0] =~ s/#\ //;
		@fields = split(/\,/,$rows[0]);
	} else {
		print "Can't find csv header !";
		exit 3;
	}

	my %stats = ();
	for ( my $y = 1; $y < $#rows; $y++ ) {
		my @values = split(/\,/,$rows[$y]);
		if ( !defined($stats{$values[0]}) ) {
			$stats{$values[0]} = {};
		}
		if ( !defined($stats{$values[0]}{$values[1]}) ) {
			$stats{$values[0]}{$values[1]} = {};
		}
		for ( my $x = 2,; $x <= $#values; $x++ ) {
			# $stats{pxname}{svname}{valuename}
			$stats{$values[0]}{$values[1]}{$fields[$x]} = $values[$x];
		}
	}
	my %stats2 = ();
	my %stats3 = ();
	my $okMsg = '';
	foreach my $pxname ( keys(%stats) ) {
		next if ( grep ( /^$pxname$/, @ignoreservers) );
		$stats2{$pxname} = {
			'act' => 0,
			'acttot' => 0,
			'bck' => 0,
			'bcktot' => 0,
			'scur' => 0,
			'slim' => 0,
			};
		foreach my $svname ( keys(%{$stats{$pxname}}) ) {
			if ( $stats{$pxname}{$svname}{'type'} eq '2' ) {
				my $svstatus = $stats{$pxname}{$svname}{'status'} eq 'UP';
				my $active = $stats{$pxname}{$svname}{'act'} eq '1';
				my $activeDescr = $active ? _gt("Active service") :_gt("Backup service") ;
				if ( $stats{$pxname}{$svname}{'status'} eq 'UP' ) {
					logD( sprintf(_gt("%s '%s' is up on '%s' proxy."),$activeDescr,$svname,$pxname) );
				} elsif ( $stats{$pxname}{$svname}{'status'} eq 'DOWN' ) {
						push @criticals, sprintf(_gt("%s '%s' is DOWN on '%s' proxy !"),$activeDescr,$svname,$pxname);
				} elsif ( $stats{$pxname}{$svname}{'status'} eq 'NOLB' ) {
					push @warnings, sprintf(_gt("%s '%s' is NOLB on '%s' proxy !"), $activeDescr,$svname,$pxname);
				} elsif ( $stats{$pxname}{$svname}{'status'} eq 'no check' ) {
					$stats2{$pxname}{'nocheck'}++;
				}
				if ( $stats{$pxname}{$svname}{'act'} eq '1' ) {
					$stats2{$pxname}{'acttot'}++;
					$stats2{$pxname}{'act'} += $svstatus;

				} elsif ($stats{$pxname}{$svname}{'bck'} eq '1')  {
					$stats2{$pxname}{'bcktot'}++;
					$stats2{$pxname}{'bck'} += $svstatus;
				}
				$stats2{$pxname}{'scur'} += $stats{$pxname}{$svname}{'scur'};
				logD( "Current sessions : ".$stats{$pxname}{$svname}{'scur'} );

			} elsif ( $stats{$pxname}{$svname}{'type'} eq '0' ) {
				$stats2{$pxname}{'slim'} = $stats{$pxname}{$svname}{'slim'};
			}
		}
		if ( $stats2{$pxname}{'acttot'} > 0 ) {
			$okMsg .= ' '.$pxname.' (Active: '.$stats2{$pxname}{'act'}.'/'.$stats2{$pxname}{'acttot'};
			if ( $stats2{$pxname}{'bcktot'} > 0 ) {
				$okMsg .= ' , Backup: '.$stats2{$pxname}{'bck'}.'/'.$stats2{$pxname}{'bcktot'};
			}
			if ( $stats2{$pxname}{'nocheck'} ) {
				$okMsg .= ' , no-check: '.$stats2{$pxname}{'nocheck'};
			}
			$okMsg .= ")\n";
			$stats3{'items'}++;
			$stats3{'act'} += $stats2{$pxname}{'act'};
			$stats3{'acttot'} += $stats2{$pxname}{'acttot'};
			$stats3{'bck'} += $stats2{$pxname}{'bck'};
			$stats3{'bcktot'} += $stats2{$pxname}{'bcktot'};
			if ($stats2{$pxname}{'nocheck'}) { $stats3{'nocheck'} += $stats2{$pxname}{'nocheck'}; }
		}
	}
	$message = ' '.$stats3{'items'}.' items, '.$stats3{'act'}.'/'.$stats3{'acttot'}.' active';
	if ($stats3{'bcktot'} > 0 ) {
		$message .= ' '.$stats3{'bck'}.'/'.$stats3{'bcktot'}.' backup';
	}
	if ($stats3{'nocheck'}  ) {
		$message .= ' '.$stats3{'nocheck'}.' no-check';
	} 
	if ($DEBUG or $verbose) {
		$message .= "\n".$okMsg;
	} 
#	print Dumper(\%stats2);
	
}

if (@criticals > 0) {
	print "CRITICAL: ";
	print join(", ",@criticals);
	print "\n";
	exit 2;
} elsif (@warnings > 0) {
	print "WARNING: ";
	print join(", ", @warnings);
	print "\n";
	exit 1;
} else {
	print "OK: ";
	print $message;
	print "\n";
	exit 0;
}

sub logD {
	print STDERR 'DEBUG:   '.$_[0]."\n" if ($DEBUG);
}
sub logW {
	print STDERR 'WARNING: '.$_[0]."\n" if ($DEBUG);
}
# Gettext wrapper
sub _gt {
	return gettext($_[0]);
}

=head1 AUTHOR

Stéphane Urbanovski <stephane.urbanovski@ac-nancy-metz.fr>

David BERARD <david@nfrance.com>

Liam Macgillavry <liam@kumina.nl>

=cut

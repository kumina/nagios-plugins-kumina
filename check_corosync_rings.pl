#!/usr/bin/perl
#
# check_corosync_rings
#
# Copyright © 2011 Phil Garner, Sysnix Consultants Limited
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Authors: Phil Garner - phil@sysnix.com & Peter Mottram peter@sysnix.com
#
# v0.1 05/01/2011
# v0.2 31/10/2011 - additional crit when closing the file handle and additional 
#                   comments added
#
# NOTE:- Requires Perl 5.8 or higher & the Perl Module Nagios::Plugin
#        Nagios user will need sudo acces - suggest adding line below to
#        sudoers.
#        nagios  ALL=(ALL) NOPASSWD: /usr/sbin/corosync-cfgtool -s
#
#        In sudoers if requiretty is on (off state is default)
#        you will also need to add the line below
#        Defaults:nagios !requiretty
#

use warnings;
use strict;
use Nagios::Plugin;

# Lines below may need changing if corosync-cfgtool or sudo installed in a
# diffrent location.

my $sudo    = '/usr/bin/sudo';
my $cfgtool = '/usr/sbin/corosync-cfgtool -s';

# Now set up the plugin
my $np = Nagios::Plugin->new(
    shortname => 'check_cororings',
    version   => '0.2',
    usage     => "Usage: %s <ARGS>\n\t\t--help for help\n",
    license   => "License - GPL v3 see code for more details",
    url       => "http://www.sysnix.com",
    blurb =>
"\tNagios plugin that checks the status of corosync rings, requires Perl         \t5.8+ and CPAN modules Nagios::Plugin.",
);

#Args
$np->add_arg(
    spec => 'rings|r=s',
    help =>
'How many rings should be running (optinal) sends Crit if incorrect number of rings found.',
    required => 0,
);

$np->getopts;

my $found = 0;
my $fh;
my $rings = $np->opts->rings;

# Run cfgtools spin through output and get info needed

open( $fh, "$sudo $cfgtool |" )
  or $np->nagios_exit( CRITICAL, "Running corosync-cfgtool failed" );

foreach my $line (<$fh>) {
    if ( $line =~ m/status\s*=\s*(\S.+)/ ) {
        my $status = $1;
        if ( $status =~ m/^ring (\d+) active with no faults/ ) {
            $np->add_message( OK, "ring $1 OK" );
        }
        else {
            $np->add_message( CRITICAL, $status );
        }
        $found++;
    }
}

close($fh) or $np->nagios_exit( CRITICAL, "Running corosync-cfgtool failed" );

# Check we found some rings and apply -r arg if needed
if ( $found == 0 ) {
    $np->nagios_exit( CRITICAL, "No Rings Found" );
}
elsif ( defined $rings && $rings != $found ) {
    $np->nagios_exit( CRITICAL, "Expected $rings rings but found $found" );
}

$np->nagios_exit( $np->check_messages() );

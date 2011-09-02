#!/usr/bin/perl -w

####################################################
# check_heartbeat_link v0.1.1			   #
# by Brandon Lee Poyner    bpoyner / CCAC.edu      #
####################################################

use strict;
use File::Basename;
use Getopt::Long;
use Sys::Hostname;

my $prog_name=basename($0);
my $prog_revision='0.1.1';
my ($debug_mode);
my $hb_node = hostname;
my $cl_status = "/usr/bin/cl_status";
my @nodes;
my (%node, %if, %exclude);

my %errorcodes = (
        'OK' => { 'value' => 0 },
        'WARNING' => { 'value' => 1 },
        'CRITICAL' => { 'value' => 2 },
        'UNKNOWN' => { 'value' => 3 }
);

&parse_options;
&check_cl_status;
&check_heartbeat_status;
&find_nodes;
&find_links;
&check_links;
&myexit('UNKNOWN',"$prog_name should never reach here");

sub print_usage {
	print <<EOF
Usage: $prog_name [ -p path ] [-n node name ] [ -x exclude node ] [--debug]
	Options:
	-n STRING [ Hostname of our node. ]
	-p STRING [ Path to cl_status.  Default: $cl_status ]
	-x STRING [ Exclude hostname from check ]
EOF
}

sub print_revision {
	print <<EOF;
$prog_name $prog_revision

The nagios plugins come with ABSOLUTELY NO WARRANTY. You may redistribute
copies of the plugins under the terms of the GNU General Public License.
For more information about these matters, see the file named COPYING.
EOF

}

sub print_help {
	&print_revision;
	print "\n";
	&print_usage;
        print <<EOF;

Send email to nagios-users\@lists.sourceforge.net if you have questions
regarding use of this software. To submit patches or suggest improvements,
send email to nagiosplug-devel\@lists.sourceforge.net
EOF
        exit $errorcodes{'UNKNOWN'}->{'value'};
}

sub parse_options {
	my ($help, $version, $debug, $exclude_node, @exclude); 
	#
	# Get command line options
	#
	GetOptions("h|help" => \$help,
		"V|version" => \$version,
		"n|node=s" => \$hb_node,
		"p|path=s" => \$cl_status,
		"x|exclude=s" => \$exclude_node,
		"debug" => \$debug);
	if (defined($help) && ($help ne "")) {
		&print_help;
		exit $errorcodes{'UNKNOWN'}->{'value'};
	}
	if (defined($version) && ($version ne "")) {
		&print_revision;
		exit $errorcodes{'UNKNOWN'}->{'value'};
	}
	if (defined($exclude_node) && ($exclude_node ne "")) {
		@exclude=split(/,/,$exclude_node);
		for my $i ( @exclude ) {
			$exclude{$i} = 1;
		}
	}
	if (defined($debug) && ($debug ne "")) {
		# 
		# Debugging information
		#
		$debug_mode=1;
		print STDERR "<$prog_name settings>\n";
		printf STDERR "Heartbeat Node: %s\n", defined($hb_node)?$hb_node:"";
		printf STDERR "Heartbeat Exclude Node: %s\n", @exclude?join(" ",@exclude):"";
		printf STDERR "Path to cl_status: %s\n", defined($cl_status)?$cl_status:"";
		print STDERR "</$prog_name settings>\n";
	}
}

sub check_cl_status {
	#
	# Bail out if cl_status is not executable
	#
	if ( ! -x "$cl_status" ) {
		&myexit('CRITICAL',"$prog_name could not execute $cl_status");	
	}
}

sub check_heartbeat_status {
	#
	# Check to see if heartbeat is running
	#
	my ($result);
	open(CL,"$cl_status hbstatus|") || &myexit('CRITICAL',"Could not open $cl_status");
	while(<CL>) {
		chop($_);
		$result .= $_;
	}
	close(CL);
	if ($? > 0) {
		&myexit('CRITICAL',sprintf("%s",defined($result)?$result:"Unknown error"));
	}
}

sub find_nodes {
	#
	# Find all nodes that are not ourself and not on the exclude list
	#
	my $self;
	my @exclude;
	open(CL,"$cl_status listnodes|") || &myexit('CRITICAL',"Could not open $cl_status");
	while(<CL>) {
		chop($_);
		if (defined($exclude{$_})) {
			push(@exclude,$_);
		} elsif ($_ ne $hb_node) {
			push(@nodes,$_);
		} else {
			$self = $_;
		}
	}
	close(CL);
	if ((defined($debug_mode)) && ($debug_mode == 1)) {
		# 
		# Debugging information
		#
		print STDERR "<$prog_name nodes>\n";
		printf STDERR "Heartbeat Exclude Nodes: %s\n", @exclude?join(" ",sort(@exclude)):"";
		printf STDERR "Heartbeat External Nodes: %s\n", @nodes?join(" ",sort(@nodes)):"";
		printf STDERR "Heartbeat Internal Nodes: %s\n", defined($self)?$self:"";
		print STDERR "</$prog_name nodes>\n";
	}
	if (!(@nodes)) {
		&myexit('CRITICAL',"No other nodes found");
	}
}

sub find_links {
	#
	# For nodes we wish to check, find all available links
	#
	for my $node (@nodes) {
		my $count = 0;
		open(CL,"$cl_status listhblinks $node|") || &myexit('CRITICAL',"Could not open $cl_status");
		while(<CL>) {
			if (/^\s*(.*)/) {
				$if{$node}{$1} = $1;
				$node{$node} = $node;
				$count++;
			}
		}
		close(CL);
	}
	if ((defined($debug_mode)) && ($debug_mode == 1)) {
		# 
		# Debugging information
		#
		print STDERR "<$prog_name interfaces>\n";
		for my $key ( values %node ) {
			for my $key2 ( keys %{$if{$key}} ) {
				print STDERR "$key $key2\n";
			}
		}
		print STDERR "</$prog_name interfaces>\n";
	}
}

sub check_links {
	#
	# Now that we have nodes and link types, check them.
	#
	my ($result);
	my ($critical)=0;
	for my $key ( values %node ) {
		for my $key2 ( keys %{$if{$key}} ) {
			open(CL,"$cl_status hblinkstatus $key $key2|") || &myexit('CRITICAL',"Could not open $cl_status");
			while(<CL>) {
				chop($_);
				$result .= "$key:$key2:$_ ";
			}
			close(CL);
			if ($? > 0) {
				$critical = 1;
			}
		}
	}
	if ($critical == 1) {
		&myexit('CRITICAL',"$result");
	} else {
		&myexit('OK',"$result");
	}
}

sub myexit {
	#
	# Print status message and exit
	#
	my ($error, $message) = @_;
	if (!(defined($errorcodes{$error}))) {
		printf STDERR "Error code $error not known\n";
		print "Heartbeat Link UNKNOWN: $message\n";
		exit $errorcodes{'UNKNOWN'}->{'value'};
	}
	print "Heartbeat Link $error: $message\n";
	exit $errorcodes{$error}->{'value'};
}

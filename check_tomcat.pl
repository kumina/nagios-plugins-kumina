#!/usr/bin/perl 

#############################################################################
#                                                                           #
# This script was initially developed by Lonely Planet for internal use     #
# and has kindly been made available to the Open Source community for       #
# redistribution and further development under the terms of the             #
# GNU General Public License v3: http://www.gnu.org/licenses/gpl.html       #
#                                                                           #
#############################################################################
#                                                                           #
# This script is supplied 'as-is', in the hope that it will be useful, but  #
# neither Lonely Planet nor the authors make any warranties or guarantees   #
# as to its correct operation, including its intended function.             #
#                                                                           #
# Or in other words:                                                        #
#       Test it yourself, and make sure it works for YOU.                   #
#                                                                           #
#############################################################################
# Author: George Hansper                     e-mail:  george@hansper.id.au  #
#############################################################################

use strict;
use LWP;
use LWP::UserAgent;
use Getopt::Std;
use XML::XPath;

my %optarg;
my $getopt_result;

my $lwp_user_agent;
my $http_request;
my $http_response;
my $url;
my $body;

my @message;
my @message_perf;
my $exit = 0;
my @exit = qw/OK: WARNING: CRITICAL:/;

my $rcs_id = '$Id: check_tomcat.pl,v 1.3 2011/12/11 04:56:27 george Exp $';
my $rcslog = '
	$Log: check_tomcat.pl,v $
	Revision 1.3  2011/12/11 04:56:27  george
	Added currentThreadCount to performance data.

	Revision 1.2  2011/11/18 11:30:57  george
	Added capability to extract the connector names, and check any or all tomcat connectors for sufficient free threads.
	Stripped quotes from connector names to work around tomcat7 quirkiness.

	Revision 1.1  2011/04/16 12:05:26  george
	Initial revision

	';

# Defaults...
my $timeout = 10;			# Default timeout
my $host = 'localhost';		# default host header
my $host_ip = 'localhost';		# default IP
my $port = 80; 			# default port
my $user = 'nagios';		# default user
my $password = 'nagios';	# default password
my $uri = '/manager/status?XML=true';			#default URI
my $http = 'http';
my $connector_arg = undef;
my $warn_threads = "25%";
my $crit_threads = "10%";
# Memory thresholds are tight, because garbage collection kicks in only when memory is low anyway
my $warn_memory = "5%";
my $crit_memory = "2%";

my $xpath;
my %xpath_checks = (
	maxThreads => '/status/connector/threadInfo/@maxThreads',
	currentThreadCount => '/status/connector/threadInfo/@currentThreadCount',
	currentThreadsBusy => '/status/connector/threadInfo/@currentThreadsBusy',
	memMax => '/status/jvm/memory/@max',
	memFree => '/status/jvm/memory/@free',
	memTotal => '/status/jvm/memory/@total',
);
# XPath examples...
# /status/jvm/memory/@free
# /status/connector[attribute::name="http-8080"]/threadInfo/@maxThreads
# /status/connector/threadInfo/@*	<- returns multiple nodes

my %xpath_check_results;

sub VERSION_MESSAGE() {
	print "$^X\n$rcs_id\n";
}

sub HELP_MESSAGE() {
	print <<EOF;
Usage:
	$0 [-v] [-H hostname] [-I ip_address] [-p port] [-S] [-t time_out] [-l user] [-a password] [-w /xpath[=value]...] [-c /xpath[=value]...]

	-H  ... Hostname and Host: header (default: $host)
	-I  ... IP address (default: none)
	-p  ... Port number (default: ${port})
	-S  ... Use SSL connection
	-v  ... verbose messages
	-t  ... Seconds before connection times out. (default: $timeout)
	-l  ... username for authentication (default: $user)
	-a  ... password for authentication (default: embedded in script)
	-u  ... uri path, (default: $uri)
	-n  ... connector name, regular expression
		eg 'ajp-bio-8009' or 'http-8080' or '^http-'.
		default is to check: .*-port_number\$
		Note: leading/trailing quotes and spaces are trimmed from the connector name for matching.
	-w  ... warning thresholds for threads,memory (memory in MB)
		eg 20,50 or 10%,25% default is $warn_threads,$warn_memory
	-c  ... critical thresholds for threads,memory (memory in MB)
		eg 10,20 or 5%,10%, default is $crit_threads,$crit_memory
Example:
	$0 -H app01.signon.devint.lpo -p 8080 -t 5 -l nagios -a apples -u '/manager/status?XML=true'
	$0 -H app01.signon.devint.lpo -p 8080 -w 10%,50 -c 5%,10
	$0 -H app01.signon.devint.lpo -p 8080 -w 10%,50 -c 5%,10 -l admin -a admin -n .

Notes:
	The -I parameters connects to a alternate hostname/IP, using the Host header from the -H parameter
	
	To check ALL connectors mentioned in the status XML file, use '-n .'
	'.' is a regular expression matching all connector names.
	
EOF
}

$getopt_result = getopts('hvSH:I:p:w:c:t:l:a:u:n:', \%optarg) ;

# Any invalid options?
if ( $getopt_result == 0 ) {
	HELP_MESSAGE();
	exit 1;
}
if ( $optarg{h} ) {
	HELP_MESSAGE();
	exit 0;
}

sub printv($) {
	if ( $optarg{v} ) {
		chomp( $_[-1] );
		print STDERR @_;
		print STDERR "\n";
	}
}

if ( defined($optarg{t}) ) {
	$timeout = $optarg{t};
}

# Is port number numeric?
if ( defined($optarg{p}) ) {
	$port = $optarg{p};
	if ( $port !~ /^[0-9][0-9]*$/ ) {
		print STDERR <<EOF;
		Port must be a decimal number, eg "-p 8080"
EOF
	exit 1;
	}
}

if ( defined($optarg{H}) ) {
	$host = $optarg{H};
	$host_ip = $host;
}

if ( defined($optarg{I}) ) {
	$host_ip = $optarg{I};
	if ( ! defined($optarg{H}) ) {
		$host = $host_ip;
	}
}

if ( defined($optarg{l}) ) {
	$user = $optarg{l};
}

if ( defined($optarg{a}) ) {
	$password = $optarg{a};
}

if ( defined($optarg{u}) ) {
	$uri = $optarg{u};
}

if ( defined($optarg{S}) ) {
	$http = 'https';
}

if ( defined($optarg{c}) ) {
	my @threshold = split(/,/,$optarg{c});
	if ( $threshold[0] ne "" ) {
		$crit_threads = $threshold[0];
	}
	if ( $threshold[1] ne "" ) {
		$crit_memory = $threshold[1];
	}
}

if ( defined($optarg{n}) ) {
	$connector_arg = $optarg{n};
} else {
	$connector_arg = "-$port\$";
}

if ( defined($optarg{w}) ) {
	my @threshold = split(/,/,$optarg{w});
	if ( $threshold[0] ne "" ) {
		$warn_threads = $threshold[0];
	}
	if ( $threshold[1] ne "" ) {
		$warn_memory = $threshold[1];
	}
}

*LWP::UserAgent::get_basic_credentials = sub {
        return ( $user, $password );
};

# print $xpath_checks[0], "\n";

printv "Connecting to $host:${port}\n";

$lwp_user_agent = LWP::UserAgent->new;
$lwp_user_agent->timeout($timeout);
if ( $port == 80 || $port == 443 || $port eq "" ) {
	$lwp_user_agent->default_header('Host' => $host);
} else {
	$lwp_user_agent->default_header('Host' => "$host:$port");
}

$url = "$http://${host_ip}:${port}$uri";
$http_request = HTTP::Request->new(GET => $url);

printv "--------------- GET $url";
printv $lwp_user_agent->default_headers->as_string . $http_request->headers_as_string;

$http_response = $lwp_user_agent->request($http_request);
printv "---------------\n" . $http_response->protocol . " " . $http_response->status_line;
printv $http_response->headers_as_string;
printv "Content has " . length($http_response->content) . " bytes \n";

if ($http_response->is_success) {
	$body = $http_response->content;
	my $xpath = XML::XPath->new( xml => $body );
	my $xpath_check;
	# Parse the data out of the XML...
	foreach $xpath_check ( keys %xpath_checks ) {
		#print keys(%{$xpath_check}) , "\n";
		my $path = $xpath_checks{$xpath_check};
		$path =~ s{\$port}{$port};
		#print $xpath_check->{xpath} , "\n";
		my $nodeset = $xpath->find($path);
		if ( $nodeset->get_nodelist == 0 ) {
			push @message, "$path not found";
			$exit |= 2;
			push @message_perf, "$path=not_found";
			next;
		}
		foreach my $node ($nodeset->get_nodelist) {
			my $connector_name = $node->getParentNode()->getParentNode()->getAttribute("name");
			$connector_name =~ s/^["'\s]+//;
			$connector_name =~ s/["'\s]+$//;
			my $value = $node->string_value();
			if ( $value =~ /^"?([0-9.]+)"?$/ ) {
				$value = $1;
			} else {
				push @message, "$path is not numeric";
				$exit |= 2;
				push @message_perf, "$path=not_numeric";
				next;
			}
			if ( $xpath_check =~ /^mem/ ) {
				# This is the .../memory/.. xpath, just store the value in the hash
				$xpath_check_results{$xpath_check} = $value;
			} elsif ( $connector_name =~ /${connector_arg}/ && $connector_name ne "" ) {
				# This is a .../threadInfo/... xpath, put the result into a hash (key is connector_name)
				$xpath_check_results{$xpath_check}{$connector_name} = $value;
			}
		}
	}
	# Now apply the logic and check the results
	#----------------------------------------------
	# Check memory
	#----------------------------------------------
	my $jvm_mem_available = $xpath_check_results{memFree} + $xpath_check_results{memMax} - $xpath_check_results{memTotal};
	printv(sprintf("free=%d max=%d total=%d",$xpath_check_results{memFree}/1024, $xpath_check_results{memMax}/1024, $xpath_check_results{memTotal}/1024));
	if ( $warn_memory =~ /(.*)%$/ ) {
		$warn_memory = int($1 * $xpath_check_results{memMax} / 100);
	} else {
		# Convert to bytes
		$warn_memory =int($warn_memory * 1024 * 1024);
	}
	printv("warning at $warn_memory bytes (". ( $warn_memory / 1024 /1024 )."MB) free, max=$xpath_check_results{memMax}");
	
	if ( $crit_memory =~ /(.*)%$/ ) {
		$crit_memory = int($1 * $xpath_check_results{memMax} / 100);
	} else {
		# Convert to bytes
		$crit_memory = int($crit_memory * 1024 * 1024);
	}
	printv("critical at $crit_memory bytes (". ( $crit_memory / 1024 /1024 )."MB) free, max=$xpath_check_results{memMax}");
	
	if ( $jvm_mem_available <= $crit_memory ) {
		$exit |= 2;
		push @message, sprintf("Memory critical <%d MB,",$crit_memory/1024/1024);
	} elsif ( $jvm_mem_available <= $warn_memory ) {
		$exit |= 1;
		push @message, sprintf("Memory low <%d MB,",$warn_memory/1024/1024);
	}
	push @message, sprintf("memory in use %d MB (%d MB);",
		( $xpath_check_results{memMax} - $jvm_mem_available ) / ( 1024 * 1024),
		$xpath_check_results{memMax} / ( 1024 * 1024) 
		);
	push @message_perf, "used=".( $xpath_check_results{memMax} - $jvm_mem_available ) . " free=$jvm_mem_available max=$xpath_check_results{memMax}";

	#----------------------------------------------
	# Check threads
	#----------------------------------------------
	my $name;
	foreach $name ( keys( %{$xpath_check_results{currentThreadsBusy}} ) ) {

		if ( $warn_threads =~ /(.*)%$/ ) {
			$warn_threads = int($1 * $xpath_check_results{maxThreads}{$name} / 100);
		}
		printv("warning at $warn_threads threads free, max=$xpath_check_results{maxThreads}{$name}");

		if ( $crit_threads =~ /(.*)%$/ ) {
			$crit_threads = int($1 * $xpath_check_results{maxThreads}{$name} / 100);
		}
		printv("critical at $crit_threads threads free, max=$xpath_check_results{maxThreads}{$name}");

		my $threads_available = $xpath_check_results{maxThreads}{$name} - $xpath_check_results{currentThreadsBusy}{$name};
		if ( $threads_available <= $crit_threads ) {
			$exit |= 2;
			push @message, sprintf("Critical: free_threads<%d",$crit_threads);
		} elsif ( $threads_available <= $warn_threads ) {
			$exit |= 1;
			push @message, sprintf("Warning: free_threads<%d",$warn_threads);
		}
		push @message, sprintf("threads[$name]=%d(%d);",
			$xpath_check_results{currentThreadsBusy}{$name},
			$xpath_check_results{maxThreads}{$name}
			);
		if ( defined($optarg{n}) ) {
			push @message_perf, "currentThreadsBusy[$name]=$xpath_check_results{currentThreadsBusy}{$name} currentThreadCount[$name]=$xpath_check_results{currentThreadCount}{$name} maxThreads[$name]=$xpath_check_results{maxThreads}{$name}";
		} else {
			# For the sake of backwards-compatability of graphs etc...
			push @message_perf, "currentThreadsBusy=$xpath_check_results{currentThreadsBusy}{$name} currentThreadCount=$xpath_check_results{currentThreadCount}{$name} maxThreads=$xpath_check_results{maxThreads}{$name}";
		}
	}
	if ( keys(%{$xpath_check_results{currentThreadsBusy}}) == 0 ) {
		# no matching connectors found - this is not OK.
		$exit |= 1;
		push @message, "Warning: No tomcat connectors matched name =~ /$connector_arg/";
	}
} elsif ( $http_response->code == 401 ) {
	print "WARNING: $url " . $http_response->protocol . " " . $http_response->status_line ."\n";
	exit 1;
} else {
	print "CRITICAL: $url " . $http_response->protocol . " " . $http_response->status_line ."\n";
	exit 2;
}

if ( $exit == 3 ) {
	$exit = 2;
}

print "$exit[$exit] ". join(" ",@message) . "|". join(" ",@message_perf) . "\n";
exit $exit;

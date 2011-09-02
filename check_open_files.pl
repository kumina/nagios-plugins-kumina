#!/usr/bin/perl

use Getopt::Long;
use vars qw($opt_h $PROGNAME $opt_w $opt_c $opt_t $opt_vi $msg $state);
use lib "/usr/lib/nagios/plugins";
use utils qw(%ERRORS &print_revision &support &usage );

sub print_help ();
sub print_usage ();
sub process_arguments();

Getopt::Long::Configure('bundling');
$status=process_arguments();
if ($status){
	print "ERROR:  Processing Arguments\n";
	exit $ERRORS{'WARNING'};
	}
	
$SIG{'ALRM'} = sub {
        print ("ERROR: timed out waiting for $PROGNAME \n");
	        exit $ERRORS{"WARNING"};
};
alarm($opt_t);


	
$procfile="/proc/sys/fs/file-nr";

open(FILE, $procfile) or die "$procfile not exits!";
my $line=<FILE>;
close FILE;
my ($nb_openfiles, $nb_freehandlers, $file_max)= split(/\s/, $line);

### See /usr/src/linux/Documentation/sysctl/fs.txt : the real number of open files is
# the first field minus the second one
my $realfreehandlers = $nb_openfiles - $nb_freehandlers;

$warning_threshold=int($file_max * $opt_w /100);
$critical_threshold=int($file_max * $opt_c /100);

if ($realfreehandlers < $warning_threshold ){
	$msg = "OK: open files ($realfreehandlers) is below threshold ($warning_threshold/$critical_threshold)";
	$state=$ERRORS{'OK'};
	}
if ($realfreehandlers >= $warning_threshold && $realfreehandlers < $critical_threshold){
	$msg = "WARNING: open files ($realfreehandlers) exceeds (threshold=$warning_threshold/$critical_threshold)";
	$state=$ERRORS{'WARNING'};
	}
if ($realfreehandlers >= $critical_threshold ){
	$msg = "CRITICAL: open files ($realfreehandlers) exceeds (threshold=$critical_threshold/$critical_threshold)";
	$state=$ERRORS{'CRITICAL'};
	}

print "$msg|open_files=$realfreehandlers;$warning_threshold;$critical_threshold\n";
exit $state;

########## SUBS ##############################################
sub process_arguments(){
	GetOptions ( 
			"w=s" => \$opt_w, "warning=s"  => \$opt_w,   # warning if above this number
	                "c=s" => \$opt_c, "critical=s" => \$opt_c,       # critical if above this number
			"t=i" => \$opt_t, "timeout=i"  => \$opt_t,
			"h"   => \$opt_h, "help"       => \$opt_h,
			"v"   => \$opt_v, "version"    => \$opt_v
		   );

	if ($opt_v){
		print_revision ($PROGNAME ,'$Revision: 1.1 $');
		exit $ERRORS{'OK'};
		}
	if ($opt_h){
		print_help();
		exit $ERRORS{'OK'};
		}
	unless (defined $opt_t){
		$opt_t = $utils::TIMEOUT;
		}
	unless (defined $opt_w && defined $opt_c){
		print_usage();
		exit $ERRORS{'UNKNOWN'};
		}
	 if ( $opt_w >= $opt_c) {
                 print "Warning (-w) cannot be greater than Critical (-c)!\n";
                 exit $ERRORS{'UNKNOWN'};
	         }
	return $ERRORS{'OK'};

}


sub print_usage () {
        print "Usage: $PROGNAME -w <warn> -c <crit> [-t <timeout>] [-v version] [-h help]\n";
}


sub print_help () {
        print_revision($PROGNAME,'$Revision: 1.1 $');
        print "Copyright (c) 2007 Christophe Thiesset\n";
        print "\n";
        print_usage();
        print "\n";
        print "   Checks the open files number against the max autorized\n";
        print "-w (--warning)   = Percentage of opened files to generate warning alert\n";
        print "-c (--critical)  = Percentage of opened files to generate critical( w < c )\n";
        print "-t (--timeout)   = Plugin timeout in seconds (default = $utils::TIMEOUT)\n";
        print "-h (--help)\n";
        print "-v (--version)\n";
        print "\n\n";
        support();
}


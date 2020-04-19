#!/usr/bin/perl -w
#
use strict;
use Getopt::Long;
use Data::Dumper;
use File::Spec ();
use File::Basename ();
my $path;

BEGIN {
    $path = File::Basename::dirname(File::Spec->rel2abs($0));
    if ($path =~ /(.*)/) {
        $path = $1;
    }
}
use lib $path;
use Task;

my($file) = undef;
my($debug) = 0;

GetOptions(
	"task|file=s"	=> \$file,
	"debug=i"	=> \$debug,
);

unless ( defined($file) ) {
	die "Usage: $0 --task=<task file> --debug=<debuglevel>\n";
}
my($task) = new Task( task => $file, debug => $debug );

$task->runtask();
__END__



#command handler=op5,check=hostcheck,state=OK
#iferror handler=exit,rc=1,msg="Host is not up, exiting task"
#wait handler=op5,check=patchstatus,state=CRITICAL
#wait handler=op5,host=dbserver,check=hostcheck,state=OK
#command handler=ansible,host=dbserver,playbook=stopdb
#wait handler=op5,host=dbserver,check=mariadb,state=CRITICAL
#command handler=ansible,playbook=autopatch
#iferror handler=ansible,playbook=autopatch
#iferror handler=exit,msg="Error with autopatch"
#wait handler=op5,check=patchstatus,state=OK
#command handler=task,name=webserver
#wait handler=sleep,timer=60
#command handler=ansible,host=dbserver,playbook=startdb
#wait handler=op5,host=dbserver,check=mariadb,state=OK
#command handler=exit,rc=0,msg="End of story"

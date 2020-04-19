package Object;

use strict;
use Carp;

our $VERSION = 'v0.0.1';

sub set($$$) {
        my($self) = shift;
        my($what) = shift;
        my($value) = shift;

        $what =~ tr/a-z/A-Z/;

        $self->{ $what }=$value;
        return($value);
}

sub get($$) {
        my($self) = shift;
        my($what) = shift;

        $what =~ tr/a-z/A-Z/;
        my $value = $self->{ $what };

        return($self->{ $what });
}

sub new {
        my $proto  = shift;
        my $class  = ref($proto) || $proto;
        my $self   = {};

        bless($self,$class);

        my(%args) = @_;

        my($key,$value);
        while( ($key, $value) = each %args ) {
                $key =~ tr/a-z/A-Z/;
                $self->set($key,$value);
        }

        return($self);
}



package Task;

use strict;
use Carp;
use Data::Dumper;

our $VERSION = 'v0.0.1';
our @ISA = qw(Object);
our $debug = 0;


sub _accessor() {
	my($self) = shift;
	my($key) = shift;
	my($value) = shift;

	return(undef) unless ( defined($key) );

	if ( defined($value) ) {
		$self->debug(8,"Setting $key to $value");
		return($self->set($key,$value));
	}
	else {
		$value = $self->get($key);
		unless ( defined($value) ) {
			$self->debug(8,"Reading $key as <undef>");
		}
		else {
			$self->debug(8,"Reading $key as $value");
		}
		return($value);
	}
	return(undef);
}

sub _ifs() { return(shift->_accessor("ifs",shift)) };
sub _program() { return(shift->_accessor("program",shift)) };
sub _task() { return(shift->_accessor("task",shift)) };
sub _taskfile() { return(shift->_accessor("taskfile",shift)) };
sub _parent() { return(shift->_accessor("parent",shift)) };
sub _child() { return(shift->_accessor("child",shift)) };
	
sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};
   bless($self,$class);

	my(%defaults) = ( 
		ifs => ";",
	);
	my(%hash) = ( %defaults, @_) ;
	$self->set("debug",$hash{debug});
	$self->_program($0);
	while ( my($key,$val) = each(%hash) ) {
		my($textval) = $val;
		$textval = "undef" unless ( $val );
		$self->debug(5,"setting $key=[$textval]");
		$self->set($key,$val);
	}

	my($taskfile) = $self->_taskfile();
	unless ( defined($taskfile) ) {
		croak "new need 'taskfile' parameter";
	}
	return($self->init());
}

sub debug() {
	my($self) = shift;
	my($level) = shift;
	my($msg) = shift;

	return unless ( defined($level) );
	unless ( $level =~ /^\d$/ ) {
		$msg = $level;
		$level = 1;
	}
	my($debug) = $self->get("debug");
	my ($package0, $filename0, $line0, $subroutine0 ) = caller(0);
	my ($package1, $filename1, $line1, $subroutine1 ) = caller(1);

	if ( $debug >= $level ) {
		chomp($msg);
		my($str) = "DEBUG($level,$debug,$subroutine1:$line0): $msg";
		print $str . "\n";
		return($str);
	}
	else {
		return(undef);
	}
}

sub init() {
	my($self) = shift;
	my(%args) = @_;
	my($taskfile) = $self->_taskfile();
	unless ( defined($taskfile) ) {
		croak "task is not defined\n";
	}
	unless ( open(TASK,"<",$taskfile) ) {
		die "Reading $taskfile $!\n";
	}
	my(%line);
	foreach ( <TASK> ) {
		next unless ( defined($_) );
		s/#.*//;	# Remove comments
		s/^\s+//;	# Remove leading spaces
		s/\s+$//;	# Remove ending spaces
		next if ( $_ =~ /^$/ );	# Remove empty lines
		next unless ( $_ =~ /^(\d+)\s+(.*)/ );
		my($line) = $1;
		my($args) = $2;
		$line{$line}=$args;
		$self->debug(1,"Setting line $line to $args");
	}
	$self->_task(\%line);
	return($self);
}

sub nextline() {
	my($self) = shift;
	my($current) = shift || -1;
	my($task) = $self->_task();

	my($line);
	foreach $line ( sort { $a <=> $b } keys %$task ) {
		next unless ( $line > $current );
		if ( $task->{$line} =~ /(\w+)\s+(.*)/ ) {
			my($function) = $1;
			my($args) = $2;
			return($line,$function,$args);
		}
	}
	return(undef,undef,undef);
}

sub sleep() {
	my($self) = shift;
	my(%args) = @_;

	my($sleep) = $args{sleep};
	if ( defined($sleep) ) {
		CORE::sleep($sleep);
	}
}

sub goto() {
	my($self) = shift;
	my(%args) = @_;

	my($line) = $args{goto};
	return(undef) unless ( defined($line) );

	my($sleep) = $args{sleep};
	if ( defined($sleep) ) {
		CORE::sleep($sleep);
	}
	return($line);
}

#
# splitter splits string "key1=val1;key2=val2;..."
# to a hash ( key1 => val1, key2 => val2, ... )
#
sub splitter() {
	my($self) = shift;
	my($args) = shift;
	my($ifs) = $self->_ifs();
	my(%res) = ();
	return(%res) unless ( defined($args) );
	foreach ( split(/\s*$ifs\s*/,$args) ) {
		next unless ( defined($_) );
		my($key,$value) = split(/\s*=\s*/,$_);
		next unless ( defined($key) );
		next unless ( defined($value) );
		$res{$key}=$value;
	}
	return(%res);
}

##############################################################################
#
# Handlers defined in this class
#
##############################################################################
# exit
# Arguments ( 
# 	rc => numeric	"exit code to be returned to operating system"
# 	msg => string	"A nice little message to be displayed"
# )
# Return nothing
##############################################################################
sub exit() {
	my($self) = shift;
	my(%args) = @_;

	my($rc) = $args{rc};
	$rc = 0 unless ( defined($rc) );

	my($msg) = $args{msg};
	if ( defined($msg) ) {
		chomp($msg);
		$self->debug(1,"Exiting with msg:$msg");
		print $msg . "\n";
	}

	my($parent) = $self->_parent();
	if ( defined($parent) ) {
		$self->debug(1,"Returning to parent task");
		return($rc);
	}
	$self->debug(1,"Exiting with rc:$rc");
	CORE::exit($rc);
}

sub execute() {
	my($self) = shift;
	my($script) = shift;
	my(%args) = @_;

	my(@cmd) = ( $script );
	my($key);
	foreach $key ( sort keys %args ) {
		next unless ( defined($key) );
		my($val) = $args{$key};
		next unless ( defined($val) );
		my($arg) = "--" . $key . "=" . $val;
		$self->debug(5,"Adding argument for $script $arg");
		push(@cmd,$arg);
	}
	$self->debug(1,"Executing script: @cmd");
	system(@cmd);
	if ($? == -1) {
		die "failed to execute: $!\n";
	}
	elsif ($? & 127) {
		die "child died with signal %d, %s coredump\n", ($? & 127),  ($? & 128) ? 'with' : 'without';
	}
	else {
		my($rc) = $? >> 8;
		$self->debug(1,"rc:$rc");
		return($rc);
	}
	return(undef);
}

sub scriptname() {
	my($self) = shift;
	my(%args) = @_;

	my ($package, $filename, $line, $sub) = caller(1);
	unless ( defined($sub) ) {
		return(undef);
	}

	$sub =~ s/.*:://;
	$sub .= "_handler";

	$self->debug(5,"Trying to find script for $sub");
	my($script) = $self->get($sub);
	unless ( defined($script) ) {
		$script = $self->_program . "." . $sub;
		$self->debug(5,"No script defined, creating from program name: $script");
	}
		
	unless ( -x $script ) {
		$self->debug(1,"$script is not executable, exiting...");
		die "$script is not executable, exiting...";
	}
	return($script);
}

##############################################################################
# task
# Arguments ( 
# )
# Return status of task
##############################################################################
sub task() {
	my($self) = shift;
	my(%args) = @_;

	$self->debug(1,"Doing da task handler");
	my($taskfile) = $args{taskfile};
	my($newtask) = new Task ( taskfile => $taskfile, debug => $self->get("debug"), parent => $self->_taskfile() );
	return(undef) unless ( $newtask );
	$self->debug(1,"Starting sub task ( $taskfile )");
	return( $newtask->runtask() );
}
##############################################################################
# ansible
# Arguments ( 
# )
# Return status of check
##############################################################################
sub ansible() {
	my($self) = shift;
	my(%args) = @_;

	$self->debug(1,"Doing da ansible handler");
	my($script) = $self->scriptname();
	return(undef) unless ( $script );
	return($self->execute($script,%args));
}
##############################################################################
# op5
# Arguments ( 
# )
# Return status of check
##############################################################################
sub op5() {
	my($self) = shift;
	my(%args) = @_;

	$self->debug(1,"Doing da op5 handler");
	my($script) = $self->scriptname();
	return(undef) unless ( $script );
	return($self->execute($script,%args));
}

#
# Execute the handler (once)
#
sub handler() {
	my($self) = shift;
	my(%args) = @_;
	my($handler) = delete $args{"handler"};
	$self->debug(1,"handler=$handler");
	if ( $self->can($handler) ) {
		return($self->$handler(%args));
	}
	else {
		print "no handler ($handler) defined in class\n";
	}
}

#
# Execute command (once)
#
sub command() {
	my($self) = shift;
	my(%args) = @_;
	return($self->handler(%args));
}

sub extra() {
	my($self) = shift;
	my(%args) = @_;
	if ( defined($args{sleep}) ) {
		$self->debug(1,"Sleeping for $args{sleep}");
		CORE::sleep($args{sleep});
	}
}

sub banner_task() {
	my($self) = shift;
	my($banner) = "";
	$banner .= "     #####    ##     ####   #    #\n";
	$banner .= "      #     #  #   #       #   #\n";
	$banner .= "     #    #    #   ####   ####\n";
	$banner .= "    #    ######       #  #  #\n";
	$banner .= "   #    #    #  #    #  #   #\n";
	$banner .= "  #    #    #   ####   #    #\n";
	return($banner);
}



sub runtask() {
	my($self) = shift;
	my($line) = -1;
	my($function) = undef;
	my($args) = undef;
	my($rc) = 0;
	my(%retry) = ();
	print $self->banner_task();
	my($taskfile) = $self->_taskfile();
	while ( $line ) {
		($line,$function,$args) = $self->nextline($line);
		next unless ( defined($line) );
		$retry{$line} = 0 unless ( defined($retry{$line}) );
		next unless ( $function );
		$function = lc($function);
		next unless ( $args );
		my(%args) = $self->splitter($args);
		print "\n=== Starting ========================================\n";
		print "taskfile: $taskfile, pid: $$, retry: $retry{$line}, line: $line, function: $function, args: $args\n";

		$self->extra(%args);

		if ( $function eq "command" ) {
			$rc = $self->command(%args);
		}
		elsif ( $function eq "iferror" ) {
			next unless ( $rc );
			if ( $args{goto} ) {
				$retry{$line}++;
				my($newline) = $self->goto(%args);
				unless ( $newline ) {
					die "Bad goto on line $line\n";
				}
				$line = $newline - 1;
				next;
			}
			else {
				$rc = $self->command(%args);
			}
			$self->debug("rc:$rc");
		}
		elsif ( $function eq "wait" ) {
			my($sleep) = 1;
			do {
				$self->sleep(%args);
				$retry{$line}++;
				print "\n*** waiting ****************************************\n";
				print "retry: $retry{$line}, line: $line, function: $function, args: $args\n";
				$rc = $self->command(%args);
			} while ( $rc );
		}

		return(undef) unless ( $line );
	}
}


1;

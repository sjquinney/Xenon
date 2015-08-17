package Xenon::Utils; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Readonly;
Readonly my $TIMEOUT_STATUS  => 254;
Readonly my $DEFAULT_TIMEOUT => 30; # seconds

sub fork_with_timeout {
    my ( $work, $timeout_time ) = @_;

    $timeout_time ||= $DEFAULT_TIMEOUT;

    my $intermediate_pid = fork();
    if ( !defined $intermediate_pid ) {
        die "Failed to fork: $!\n";
    } elsif ( $intermediate_pid == 0 ) { # child

        my $worker_pid = fork();
        if ($worker_pid == 0) {
            setpgrp(0,0);

            $work->();

            exit 0;
        }

        # Reap the worker process group if various signals are received.

        my $killer = sub { say "Killing $worker_pid process group";
                           kill -15, $worker_pid };
        local $SIG{HUP}  = $killer;
        local $SIG{TERM} = $killer;
        local $SIG{INT}  = $killer;
        local $SIG{QUIT} = $killer;

        my $watchdog_pid = fork();
        if ($watchdog_pid == 0) {
            my $endtime = time() + $timeout_time;
 
            # sleep() can wake up on signals. So keep looping until the
            # time has passed.

            while (1) {
                my $tosleep = $endtime - time();

                if ($tosleep <= 0) {
                    last;
                }

                sleep $tosleep;
            }

            exit 0;
        }

        my $exited_pid = wait();
        my $exit_status = $? >> 8;

        if ( $exited_pid == $worker_pid ) {
            kill 'KILL', $watchdog_pid;
        } else {
            $exit_status = $TIMEOUT_STATUS;
            kill 'KILL', $worker_pid;
        }

        # It is entirely possible that the final wait will hang. Deal
        # with this in a very simplistic fashion.

        {
            local $SIG{ALRM} =
                sub { die "Fatal: Child process refuses to quit\n" };
            alarm 10;
            wait;
            alarm 0;
        }

        # Reap the worker process group in case anything is still
        # running.

        kill -15, $worker_pid;

        exit $exit_status;
    }

    # Ensure the signals are passed on to the intermediate process

    local $SIG{HUP}  = sub { kill 'HUP',  $intermediate_pid };
    local $SIG{TERM} = sub { kill 'TERM', $intermediate_pid };
    local $SIG{INT}  = sub { kill 'INT',  $intermediate_pid };
    local $SIG{QUIT} = sub { kill 'QUIT', $intermediate_pid };

    waitpid $intermediate_pid, 0;
    my $status = $? >> 8;

    if ( $status == $TIMEOUT_STATUS ) {
        die "Timed out after $timeout_time seconds\n";
    }

    return $status;
}

1;
__END__

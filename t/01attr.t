#!/usr/bin/perl
use strict;
use warnings;

use v5.10;
use File::Spec ();
use File::Temp ();

use Test::More;
use Test::Exception;

{
    package Xenon::Attributes::Test;

    use Types::Standard qw(Str);
    use Moo;
    with 'Xenon::Role::AttributeManager';

    has 'mode' => (
        is      => 'ro',
        isa     => Str,
        default => '0700'
    );

    sub configure {
        my ( $self, $path ) = @_;

        chmod oct($self->mode), $path
            or die "Could not chmod $path: $!\n";

        return;
    }
}

my $test1 = Xenon::Attributes::Test->new(dryrun => 0);
isa_ok( $test1, 'Xenon::Attributes::Test' );
can_ok( $test1, 'configure', 'dryrun' );
ok( !$test1->dryrun, 'dryrun is false' );
is( $test1->mode, '0700', 'mode attr has default value');

my $tmpdir = File::Temp->newdir( 'xenonXXXXXX',
                                  TMPDIR   => 1,
                                  CLEANUP  => 1 );

my $test_file = File::Spec->catfile( $tmpdir, 'example.txt' );
my $fh = IO::File->new( $test_file, 'w' )
    or die "Could not open '$test_file': $!\n";
$fh->say('hello world');
$fh->close or die "Could not close '$test_file': $!\n";

$test1->configure($test_file);
my $req_mode = oct($test1->mode);
my $new_mode = (stat $test_file)[2] & oct('07777');

ok( $req_mode == $new_mode, 'configured file mode correctly' );

done_testing;

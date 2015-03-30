#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

use File::Temp qw(mktemp);

use Test::More;
use Test::File;

BEGIN { use_ok('Xenon::File::Link'); }

my $tmpdir = File::Temp->newdir( 'xenonXXXXXX',
                                  TMPDIR   => 1,
                                  CLEANUP  => 0 );
my $linkname = mktemp 'xenonXXXXXX';

my $linkfile = File::Spec->catfile( $tmpdir, $linkname );

my $file1 = Xenon::File::Link->new( source => '/tmp',
                                   path   => $linkfile );
$file1->configure();

symlink_target_exists_ok( $linkfile, '/tmp' );

# Same path as file1, different source, should cause update
 
my $file2 = Xenon::File::Link->new( source => '/var',
                                    path   => $linkfile );
$file2->configure();

symlink_target_exists_ok( $linkfile, '/var' );

done_testing;

#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

use File::Temp qw(mktemp);

use Test::More;
use Test::File;
use Test::Exception;

BEGIN { use_ok('Xenon::File::Link'); }

my $tmpdir = File::Temp->newdir( 'xenonXXXXXX',
                                  TMPDIR   => 1,
                                  CLEANUP  => 1 );

my $link1 = mktemp 'xenonXXXXXX';
$link1 = File::Spec->catfile( $tmpdir, $link1 );

my $file1 = Xenon::File::Link->new( source => '/tmp',
                                   path   => $link1 );
$file1->configure();

symlink_target_exists_ok( $link1, '/tmp' );

# Same path as file1, different source, should cause update
 
my $file2 = Xenon::File::Link->new( source => '/var',
                                    path   => $link1 );
$file2->configure();

symlink_target_exists_ok( $link1, '/var' );

# Dangling symlink

my $dangle = mktemp 'xenonXXXXXX';
$dangle = File::Spec->catfile( $tmpdir, $dangle );

my $link3 = mktemp 'xenonXXXXXX';
$link3 = File::Spec->catfile( $tmpdir, $link3 );

my $file3 = Xenon::File::Link->new( source => $dangle,
                                    path   => $link3 );
$file3->configure();

symlink_target_dangles_ok( $link3 );
symlink_target_is( $link3, $dangle );

# check if we can create the parent directory as well

my $subdir4 = mktemp 'xenonXXXXXX';
$subdir4 = File::Spec->catfile( $tmpdir, $subdir4 );

my $link4 = mktemp 'xenonXXXXXX';
$link4 = File::Spec->catfile( $subdir4, $link4 );

my $file4 = Xenon::File::Link->new( source => '/tmp',
                                    path   => $link4 );

throws_ok { $file4->configure() } qr/^Parent directory /, 'mkdir option required';

$file4 = Xenon::File::Link->new( source => '/tmp',
                                 path   => $link4,
                                 mkdir => 1 );
$file4->configure();
symlink_target_exists_ok( $link4, '/tmp' );

done_testing;

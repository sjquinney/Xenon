#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use File::Temp qw(mktemp);

use Test::More;
use Test::File;
use Test::Exception;

BEGIN { use_ok('Xenon::File::Directory'); }

my $tmpdir = File::Temp->newdir( 'xenonXXXXXX',
                                  TMPDIR   => 1,
                                  CLEANUP  => 1 );

my $dir1 = mktemp 'xenonXXXXXX';
$dir1 = File::Spec->catfile( $tmpdir, $dir1 );

my $file1 = Xenon::File::Directory->new( path => $dir1 );
$file1->configure();

dir_exists_ok($dir1);

# check if we can create the parent directory as well

my $subdir2 = mktemp 'xenonXXXXXX';
$subdir2 = File::Spec->catfile( $tmpdir, $subdir2 );

my $dir2 = mktemp 'xenonXXXXXX';
$dir2 = File::Spec->catfile( $subdir2, $dir2 );

my $file2 = Xenon::File::Directory->new( path => $dir2 );

throws_ok { $file2->configure() } qr/^Parent directory /, 'mkdir option required';

$file2 = Xenon::File::Directory->new( path => $dir2, mkdir => 1 );
$file2->configure();

dir_exists_ok($dir2);

done_testing;

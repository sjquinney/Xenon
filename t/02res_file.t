#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Cwd;
use File::Spec;

use Test::More tests => 11;
use Test::Exception;

BEGIN { use_ok( 'Xenon::Resource::File' ); }

my $res1 = Xenon::Resource::File->new( source => '/dev/null' );

isa_ok( $res1, 'Xenon::Resource::File' );

can_ok( $res1, 'source', 'fetch' );

isa_ok( $res1->source, 'Path::Tiny' );

is( $res1->source, '/dev/null', 'source path (/dev/null)' );
is( $res1->source->basename, 'null', 'basename of source path' );

is( $res1->fetch, '', 'source contents (/dev/null)' );

# Test failure to fetch when path is not a file

my $res2 = Xenon::Resource::File->new( source => '/tmp' );
throws_ok { $res2->fetch } qr/^Cannot fetch/, 'bad source exception';

my $res3 = Xenon::Resource::File->new( source => 't/data/source1' );

my $cwd = getcwd;
my $dir = File::Spec->catdir( $cwd, 't', 'data' );
my $fullpath = File::Spec->catfile( $dir, 'source1' );
is( $res3->source->parent, $dir, 'relative to absolute path conversion' );
is( $res3->source, $fullpath,  'relative to absolute path conversion' );

my $data = do { local $/; <DATA> };

is( $res3->fetch, $data, 'fetch data from file' );


__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

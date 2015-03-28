#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More tests => 7;

BEGIN { use_ok( 'Xenon::Resource::Inline' ); }

my $res1 = Xenon::Resource::Inline->new( source => '' );

isa_ok( $res1, 'Xenon::Resource::Inline' );

can_ok( $res1, 'source', 'fetch' );

is( $res1->source, '', 'source path (null)' );

is( $res1->fetch, '', 'source contents (null)' );

my $data = do { local $/; <DATA> };

my $res2 = Xenon::Resource::Inline->new( source => $data );

is( $res2->source, $data, 'inline source' );

is( $res2->fetch, $data, 'inline fetch' );


__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

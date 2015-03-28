#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More tests => 7;

BEGIN { use_ok( 'Xenon::Resource::URI' ); }

my $res1 = Xenon::Resource::URI->new( source => 'file:///dev/null' );

isa_ok( $res1, 'Xenon::Resource::URI' );

can_ok( $res1, 'source', 'fetch' );

isa_ok( $res1->source, 'URI' );

is( $res1->source, 'file:///dev/null', 'source path (null)' );

is( $res1->fetch, '', 'source contents (null)' );

my $data = do { local $/; <DATA> };

my $res2 = Xenon::Resource::URI->new( source => '/dev/null' );
is( $res2->source, 'file:///dev/null', 'path converted to file URI' );

__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

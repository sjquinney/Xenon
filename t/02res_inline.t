#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More tests => 10;
use Test::Exception;

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

my $data_ref = \$data;
my $res3 = Xenon::Resource::Inline->new( source => $data_ref );

is( $res3->source, $data_ref, 'inline source reference' );

is( $res3->fetch, $data, 'inline fetch from reference' );

dies_ok { Xenon::Resource::Inline->new( source => [] ) } 'dies on bad data';

__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

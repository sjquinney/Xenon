#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More tests => 4;

BEGIN { use_ok( 'Xenon::ContentDecoder::Base64' ); }

my $decoder = Xenon::ContentDecoder::Base64->new();

isa_ok( $decoder, 'Xenon::ContentDecoder::Base64' );

can_ok( $decoder, 'decode' );

is( $decoder->decode('aGVsbG8gd29ybGQ='), 'hello world', 'decode test' );

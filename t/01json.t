#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More;
use Test::Exception;

{
    package Xenon::Test;

    use Moo;
    use Types::Standard qw(Str);
    with 'Xenon::Role::ConfigFromJSON';

    has 'foo' => (
        is      => 'ro',
        isa     => Str,
        default => 'default_value',
    );

}

# Load inline JSON data
my $test1 = Xenon::Test->new_from_json( \ '{"foo":"bar1"}' );

isa_ok( $test1, 'Xenon::Test' );
can_ok( $test1, 'new_from_json' );
is( $test1->foo, 'bar1', 'foo attribute has correct value' );

# Load JSON data from file
my $test2 = Xenon::Test->new_from_json('t/data/json_config1.json');

isa_ok( $test2, 'Xenon::Test' );
can_ok( $test2, 'new_from_json' );
is( $test2->foo, 'bar2', 'foo attribute has correct value' );

# Load JSON data from Path::Tiny file
use Path::Tiny;
my $path = path("t/data/json_config2.json");
my $test3 = Xenon::Test->new_from_json($path);

isa_ok( $test3, 'Xenon::Test' );
can_ok( $test3, 'new_from_json' );
is( $test3->foo, 'bar3', 'foo attribute has correct value' );

# Acts like new() when nothing specified
my $test4 = Xenon::Test->new_from_json();
is( $test4->foo, 'default_value', 'foo attribute has default value' );

# Overrides

my $test5 = Xenon::Test->new_from_json( \ '{"foo":"bar1"}', foo => 'test5' );
is( $test5->foo, 'test5', 'foo attribute has overridden value' );

my $test6 = Xenon::Test->new_from_json( \ '{"foo":"bar1"}', { foo => 'test6' } );
is( $test6->foo, 'test6', 'foo attribute has overridden value' );

# File does not exist
throws_ok { Xenon::Test->new_from_json( 't/data/nonexistent.json' ) } qr/^Cannot load JSON from/, 'dies for non-existent file';

# Bad json
throws_ok { Xenon::Test->new_from_json( 't/data/bad.json' ) } qr/^Failed to decode JSON data:/, 'dies for bad json data';

done_testing;

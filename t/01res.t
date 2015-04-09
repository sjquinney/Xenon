#!/usr/bin/perl
use strict;
use warnings;

use v5.10;

use Test::More;

{
    package Xenon::Resource::Test;

    use IO::File ();

    use Moo;
    with 'Xenon::Role::Resource';

    sub fetch {
        my ($self) = @_;

        my $fh = IO::File->new( $self->source, 'r' )
            or die "Cannot open source file: $!\n";

        my $data = do { $/ = undef; <$fh> };

        return $data;
    }
}

my $res1 = Xenon::Resource::Test->new( source => 't/data/source1' );
isa_ok( $res1, 'Xenon::Resource::Test' );
can_ok( $res1, 'fetch', 'source' );

my $data = do { local $/; <DATA> };
my $tmpl = $res1->fetch();
is( $tmpl, $data, 'fetched source file' );

done_testing;

__DATA__
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad
minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in
reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

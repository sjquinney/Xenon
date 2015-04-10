package Xenon::Resource::Inline; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Types::Standard qw(ScalarRef Str);
use namespace::clean;

with 'Xenon::Role::Resource';

has '+source' => (
    isa => Str|ScalarRef[Str],
);

sub fetch {
    my ($self) = @_;

    my $source = $self->source;

    my $data;
    if ( ScalarRef->check($source) ) {
        $data = ${$source};
    } else {
        $data = $source;
    }

    return $data;
}

1;

package Xenon::Resource::Inline; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Types::Standard qw(Str);
use namespace::clean;

with 'Xenon::Role::Resource';

has '+source' => (
    isa => Str,
);

sub fetch {
    my ($self) = @_;

    return $self->source;
}

1;

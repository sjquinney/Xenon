package Xenon::Resource::File; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Types::Path::Tiny qw(AbsPath);
use namespace::clean;

with 'Xenon::Role::Resource';

has '+source' => (
    isa    => AbsPath,
    coerce => AbsPath->coercion,
);

sub fetch {
    my ($self) = @_;

    my $source = $self->source;
    if ( !$source->is_file ) {
        die "Cannot fetch '$source', it does not exist\n";
    }

    my $data = $source->slurp;

    return $data;
}

1;

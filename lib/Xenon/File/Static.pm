package Xenon::File::Static; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use namespace::clean;

with 'Xenon::Role::FileContentManager';

sub _build_pathtype {
    return 'file';
}

sub _default_options {
    return {};
}

sub build_data {
    my ( $self, $source ) = @_;

    return $source;
}

1;

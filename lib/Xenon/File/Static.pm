package Xenon::File::Static; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;

with 'Xenon::Role::FileContentManager';

use namespace::clean;

sub _default_options {
    return {};
}

sub build_data {
    my ( $self, $source ) = @_;

    return $source;
}

1;

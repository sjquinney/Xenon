package Xenon::File::LCFGTT; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;

extends 'Xenon::File::TT';

use namespace::clean;

around '_default_options' => sub {
    my ( $orig, @args ) = @_;

    my $defaults = $orig->(@args);

    # Override some settings for LCFG style templates
    return {
        %{$defaults},
        ABSOLUTE    => 1,
        ANYCASE     => 1,
        INTERPOLATE => 1,
        POST_CHOMP  => 0,
    };
};

1;

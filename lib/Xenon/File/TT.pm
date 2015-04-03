package Xenon::File::TT; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;

with 'Xenon::Role::FileContentManager';

use namespace::clean;

sub _default_options {
    return {
        ABSOLUTE    => 0,
        ANYCASE     => 0,
        INTERPOLATE => 0,
        POST_CHOMP  => 1,
        RELATIVE    => 0,
    };
}

sub build_data {
    my ( $self, $input, $vars ) = @_;

    $vars //= {};

    my %config = $self->merge_options;

    require Template;
    my $tt = Template->new(\%config) or die $Template::ERROR . "\n";

    my $data;
    $tt->process( \$input, $vars, \$data )
        or die 'Failed to process template: ' . $tt->error() . "\n";

    return $data;
}

1;

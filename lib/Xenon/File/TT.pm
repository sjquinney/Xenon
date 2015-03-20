package Xenon::File::TT; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use namespace::clean;

with 'Xenon::Role::FileContentManager';

sub _build_pathtype {
    return 'file';
}

sub default_options {
    return {
        POST_CHOMP => 1,
        RELATIVE   => 0,
        ABSOLUTE   => 0,
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

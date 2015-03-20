package Xenon::File::Link; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use English qw(-no_match_vars);
use Moo;
use Try::Tiny;
use namespace::clean;

with 'Xenon::Role::FileManager';

sub _build_pathtype {
    return 'link';
}

sub default_mode {
    return '0777';
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( $self->path->is_file && -l $self->path ) ? 1 : 0;
}

sub set_access_controls {
    return; # no-op
}

sub build {
    my ($self) = @_;

    my $target = $self->path;
    my $source = $self->source;

    if ( !$source->exists ) {
        warn "Source '$source' does not exist for '$target'\n";
    }

    try {

        my $needs_update = 1;
        if ( $target->exists ) {
            my $current = readlink "$target"
                or die "Could not read symlink '$target': $OS_ERROR\n";

            if ( $current eq "$source" ) {
                $needs_update = 0;
            } else {
                $target->remove
                    or die "Could not remove old link '$target': $OS_ERROR\n";
            }
        }

        if ($needs_update) {
            say STDERR "symlink $source $target";
            symlink "$source", "$target"
                or die "Could not symlink '$target' to '$source': $OS_ERROR\n";
        }

    } catch {
        die "Failed to configure symlink: $_";
    };

    return;
}

1;

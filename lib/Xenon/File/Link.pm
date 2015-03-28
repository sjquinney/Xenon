package Xenon::File::Link; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use English qw(-no_match_vars);
use Moo;
use Try::Tiny;
use Xenon::Constants qw(:change);
use namespace::clean;

with 'Xenon::Role::Log4perl', 'Xenon::Role::FileManager';

sub _build_pathtype {
    return 'link';
}

sub default_mode {
    return oct('0777');
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

    my $linkname = $self->path;
    my $target   = $self->source;

    if ( !$target->exists ) {
        $self->logger->warn("Target '$target' does not exist for '$linkname'");
    }

    my $change_type = $CHANGE_NONE;
    try {

        my $needs_update = 1;
        if ( $linkname->exists ) {
            my $current = readlink "$linkname"
                or die "Could not read symlink '$linkname': $OS_ERROR\n";

            if ( $current eq "$target" ) {
                $needs_update = 0;
            } else {
                $change_type = $CHANGE_UPDATED;
                $self->logger->info("Deleting symlink '$linkname' to '$target'");
                $target->remove
                    or die "Could not remove old link '$linkname': $OS_ERROR\n";
            }
        } else {
            $change_type = $CHANGE_CREATED;
        }

        if ($needs_update) {
            $self->logger->info("Creating symlink '$linkname' to '$target'");
            symlink "$target", "$linkname"
                or die "Could not symlink '$linkname' to '$target': $OS_ERROR\n";
        }

    } catch {
        die "Failed to configure symlink: $_";
    };

    return $change_type;
}

1;

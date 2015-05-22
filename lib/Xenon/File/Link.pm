package Xenon::File::Link; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use English qw(-no_match_vars);
use Moo;
use Try::Tiny;
use Xenon::Constants qw(:change);

with 'Xenon::Role::FileManager';

use namespace::clean;

sub _build_pathtype {
    return 'link';
}

sub default_mode {
    return oct('0777');
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( -l $self->path->stringify ) ? 1 : 0;
}

sub set_access_controls {
    return; # no-op
}

# Intentionally very similar to the method in the FileContentManager role

sub change_type {
    my ($self) = @_;

    my $linkname = $self->path;
    my $target   = $self->source;

    my $change_type = $CHANGE_CREATED;
    if ( $linkname->exists ) {
        my $current = readlink "$linkname"
            or die "Could not read symlink '$linkname': $OS_ERROR\n";

        if ( $current eq "$target" ) {
            $change_type = $CHANGE_NONE;
        } else {
            $change_type = $CHANGE_UPDATED;
        }
    }

    return $change_type;
}

sub build {
    my ($self) = @_;

    my $linkname = $self->path;
    my $target   = $self->source;

    if ( !$target->exists ) {
        $self->logger->warn("Target '$target' does not exist for '$linkname'");
    }

    my $change_type = $self->change_type();

    if ( $change_type != $CHANGE_NONE ) {
        $self->logger->info("Update required for symlink '$linkname'");

        if ( $change_type == $CHANGE_UPDATED && !$self->clobber ) {
            $self->logger->info("Will not clobber existing symlink '$linkname'");
            $change_type = $CHANGE_NONE;
        } elsif ( $self->dryrun ) {
            $self->logger->info("Dry-run: Will update symlink '$linkname' to '$target'");
        } else {

            try {

                # Need to remove old link first
                if ( $change_type == $CHANGE_UPDATED ) {

                    $self->logger->debug("Deleting old symlink '$linkname'");
                    $linkname->remove
                        or die "Could not remove old link '$linkname': $OS_ERROR\n";
                }

                $self->logger->debug("Creating symlink '$linkname' to '$target'");

                symlink "$target", "$linkname"
                    or die "Could not symlink '$linkname' to '$target': $OS_ERROR\n";

	    } catch {
                die "Failed to configure symlink: $_";
            };

	}

    }

    return $change_type;
}

1;

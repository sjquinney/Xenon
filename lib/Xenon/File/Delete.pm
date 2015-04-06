package Xenon::File::Delete; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Try::Tiny;
use Xenon::Constants qw(:change);

with 'Xenon::Role::FileManager', 'Xenon::Role::Backup';

use namespace::clean;

# source is meaningless for directories
has '+source' => (
    required => 0,
    init_arg => undef,
);

has '+backup_style' => (
    default => sub { 'none' },
);

sub _build_pathtype {
    return 'delete';
}

sub default_mode {
    return oct('0000');
}

sub path_type_is_correct {
    return 1;
}

sub set_access_controls {
    return; # no-op
}

sub build {
    my ($self) = @_;

    # delete the path if it exists...

    my $path = $self->path;
    if ( !$path->exists ) {
        return $CHANGE_NONE;
    }

    if ( $path->is_dir ) {
        try {

            if ($self->dryrun) {
                $self->logger->info("Dry-run: Will delete directory '$path'");
            } else {
                $path->remove_tree( { safe => 0 } );
            }

        } catch {
            die "Failed to remove directory '$path': $_\n";
        };
    } else {

        if ($self->dryrun) {
            $self->logger->info("Dry-run: Will delete file '$path'");
        } else {

            $self->make_backup();

            $path->remove or
                die "Failed to remove file '$path': $_\n";
        }

    }

    return $CHANGE_DELETED;
}

1;

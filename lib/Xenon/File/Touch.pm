package Xenon::File::Touch; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Xenon::Constants qw(:change);

with 'Xenon::Role::FileManager';

use namespace::clean;

# source is meaningless for these files
has '+source' => (
    required => 0,
    init_arg => undef,
);

sub _build_pathtype {
    return 'file';
}

sub default_mode {
    return oct('0644');
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( $self->path->is_file && !-l $self->path ) ? 1 : 0;
}

sub build {
    my ($self) = @_;

    my $target = $self->path;

    my $change_type = $CHANGE_NONE;
    if ( !$target->exists ) {
        $change_type = $CHANGE_CREATED;

        $self->logger->info("Creating empty file '$target'");

        if ($self->dryrun) {
            $self->logger->info("Dry-run: Will create empty file '$target'");
        } else {
            $target->touch();

            # If the file already exists then ACLs will have already
            # been set in the prebuild phase.

            $self->set_access_controls($target);
        }

    }

    return $change_type;
}

1;

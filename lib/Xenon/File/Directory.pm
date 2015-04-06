package Xenon::File::Directory; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use English qw(-no_match_vars);
use Moo;
use Try::Tiny;
use Xenon::Constants qw(:change);

with 'Xenon::Role::FileManager';

use namespace::clean;

# source is meaningless for directories
has '+source' => (
    required => 0,
    init_arg => undef,
);

sub _build_pathtype {
    return 'directory';
}

sub default_mode {
    return oct('0755');
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( $self->path->is_dir && !-l $self->path ) ? 1 : 0;
}

sub build {
    my ($self) = @_;

    my $target = $self->path;

    my $change_type = $CHANGE_NONE;
    try {
        if ( !$target->exists ) {
            $change_type = $CHANGE_CREATED;

            if ( $self->dryrun ) {
                $self->logger->info("Dry-run: Will create directory '$target'");
            } else {
                $self->logger->info("Creating directory '$target'");
                my %options;
                if ( $self->has_owner ) {
                    $options{owner} = $self->owner;
                }
                if ( $self->has_group ) {
                    $options{group} = $self->group;
                }
                $options{mode} = $self->required_mode;

                $target->mkpath( \%options );

                # Even though the owner/group/mode has been set when
                # creating the directory we still need to apply any
                # other ACLs. If the directory already exists then
                # this will have already been done in the prebuild
                # phase.

                $self->set_access_controls($target);
            }
        }

    } catch {
        die "Failed to create directory '$target': $_";
    };

    return $change_type;
}

1;

package Xenon::File::Directory; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use English qw(-no_match_vars);
use Moo;
use Try::Tiny;
use namespace::clean;

with 'Xenon::Role::FileManager';

# source is meaningless for directories
has '+source' => (
    required => 0,
);

sub _build_pathtype {
    return 'directory';
}

sub default_mode {
    return '0755';
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( $self->path->is_dir && !-l $self->path ) ? 1 : 0;
}

sub build {
    my ($self) = @_;

    my $target = $self->path;

    try {
        if ( !$target->exists ) {
            say STDERR "Creating directory '$target'";
            my %options;
            if ( $self->has_owner ) {
                $options{owner} = $self->owner;
            }
            if ( $self->has_group ) {
                $options{group} = $self->group;
            }
            if ( $self->has_mode ) {
                $options{mode} = oct $self->mode;
            }

            $target->mkpath( \%options );
        }


    } catch {
        die "Failed to create directory '$target': $_";
    };

    return;
}

1;

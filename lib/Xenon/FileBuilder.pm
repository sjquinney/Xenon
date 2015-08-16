package Xenon::FileBuilder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;

with 'Xenon::Role::Log4perl', 'Xenon::Role::EnvManager';

use File::Spec ();
use Scalar::Util ();
use Try::Tiny;
use Types::Standard qw(ArrayRef Bool Str);
use Types::Path::Tiny qw(AbsPath);
use Xenon::Types qw(XenonFileManager XenonFileManagerList XenonRegistry);
use Xenon::Constants qw(:change);
use namespace::clean;

has 'files' => (
    is      => 'ro',
    isa     => XenonFileManagerList,
    coerce  => XenonFileManagerList->coercion,
    builder => '_build_files',
    lazy    => 1,
);

has 'registry' => (
    is        => 'ro',
    isa       => XenonRegistry,
    predicate => 'has_registry',
);

has 'tag'      => (
    is        => 'ro',
    isa       => Str,
    predicate => 'has_tag',
);

has 'supercedes' => (
    is        => 'ro',
    isa       => ArrayRef,
    default   => sub { [] },
);

has 'dryrun' => (
    is      => 'ro',
    isa     => Bool,
    default => sub { 0 },
);

sub _build_files {
    return [];
}

sub BUILD {
    my ($self) = @_;

    if ( $self->has_registry && !$self->has_tag ) {
        die "Registry specified but no tag name given\n";
    }

}

sub sort_files_root_first {
    my ( $self, $files ) = @_;

    my $root_first = sub { $a->[0] <=> $b->[0] || $a->[2] cmp $b->[2] };

    my @sorted_files = $self->sort_files( $files, $root_first );

    return @sorted_files;
}

sub sort_files_leaves_first {
    my ( $self, $files ) = @_;

    my $leaves_first = sub { $b->[0] <=> $a->[0] || $a->[2] cmp $b->[2] };

    my @sorted_files = $self->sort_files( $files, $leaves_first );

    return @sorted_files;
}

sub sort_files {
    my ( $self, $files, $sort_sub ) = @_;

    $sort_sub //= sub { $a->[1] cmp $b->[1] };
    $files    //= $self->files;

    # This uses File::Spec so that it is possible to pass in a list of
    # strings not just Path::Tiny objects.

    my @sorted_files =
        map {
            $_->[3]
        }
        sort $sort_sub
        map {
            my $path = Scalar::Util::blessed($_) && $_->can('path') ? $_->path : $_;
            my ( $vol, $dirs, $basename ) = File::Spec->splitpath("$path");
            my @dirs = File::Spec->splitdir($dirs);
            my $depth = scalar @dirs;
            [ $depth, $path, $basename, $_ ];
        }
        @{ $files };

    return @sorted_files;
}

sub add_files {
    my ( $self, @new_files ) = @_;

    my $files = $self->files;

    for my $new_file (@new_files) {
        my $file = XenonFileManager->coerce($new_file);
        $self->logger->debug('Adding file: ' . $file->path);
        push @{$files}, $file;
    }

    return;
}

sub configure {
    my ( $self, @build_args ) = @_;

    $self->initialise_environment();

    my @changed_files;

    my %current_paths;
    for my $file ( $self->sort_files_root_first() ) {

        # Map in the current setting for the dryrun attribute
        $file->dryrun($self->dryrun);

        my $path = $file->path;

        if ( $self->has_registry ) {

            # Check that the path is not owned by any other tag

            my ( $can_register, $entry ) =
                $self->registry->can_register_path(
                    $self->tag, $self->supercedes, $path );

            if ( !$can_register ) {
                my $cur_tag = $entry->{tag};
                $self->logger->error("Cannot configure path '$path', it is owned by '$cur_tag'");
                next;
            }

        }

        # Whether we succeed or fail to configure the file we want to
        # push the path onto the list so that it doesn't get removed
        # or deregistered.

        $current_paths{"$path"} = $file;

        try {
            $self->logger->debug("Configuring path '$path'");

            my ($change_type) = $file->configure(@build_args);
            if ( $change_type != $CHANGE_NONE ) {
                push @changed_files, $path;
            }

            if ( $self->has_registry && !$self->dryrun ) {
                $self->registry->register_path(
                    $self->tag, $self->supercedes,
                    $path, $file->permanent,
                );
            }

        } catch {
            $self->logger->error("Failed to configure path '$path': $_");
        };
    }

    # Delete files by leaves-first approach so there is some chance of
    # directories being empty before any attempt is made to remove.

    if ( $self->has_registry ) {
        $self->cleanup_unmanaged_paths(\%current_paths);
    }

    return @changed_files;
}

sub cleanup_unmanaged_paths {
    my ( $self, $current_paths ) = @_;

    my @registered_paths =
        $self->registry->paths_for_tag( $self->tag, $self->supercedes );

    for my $path ( $self->sort_files_leaves_first(\@registered_paths) ) {

        if ( exists $current_paths->{"$path"} ) {
            next;
        }

        my $entry = $self->registry->get_data_for_path($path);

        # Stop here if the path is marked as permanent. Do not
        # deregister, it is useful to know which tag the path was
        # associated with when it was created.

        if ( $entry->{permanent} ) {
            next;
        }

        if ( !$self->dryrun ) {
            $self->registry->deregister_path(
                $self->tag, $self->supercedes, $path
                );
        }

        if ( !$path->exists ) {
            next;
        }

        $self->logger->info("Removing path '$path' which is now unmanaged");
        try {
            if ( $path->is_dir ) {

                # Directories are only removed when empty

                if ( scalar $path->children > 0 ) {

                    if ($self->dryrun) {
                        $self->logger->info("Dry-run: Cannot remove directory '$path': non-empty");
                    } else {
                        die "non-empty directory\n";
                    }

                } else {

                    if ($self->dryrun) {
                        $self->logger->info("Dry-run: Would remove directory '$path'");
                    } else {
                        rmdir $path or die "$!\n";
                    }

                }
            } else {

                if ($self->dryrun) {
                    $self->logger->info("Dry-run: Would remove file '$path'");
                } else {
                    $path->remove or die "$!\n";
                }

            }
        } catch {
            $self->logger->error("Failed to remove path '$path': $_");
        };

    }

    return;
}

sub load_files_directory {
    my ( $self, $directory ) = @_;

    $directory = AbsPath->coerce();

    if ( !$directory->is_dir ) {
        die "Cannot load file list from '$directory': directory is not accessible\n";
    }

    my @configs = sort { $a->basename cmp $b->basename }
                  grep { $_->is_file }
                  $directory->children( qw/\.yml$/ );

    require YAML::XS;
    local $YAML::XS::UseCode  = 0;
    local $YAML::XS::LoadCode = 0;

    for my $config (@configs) {
        try {

            my $item = YAML::XS::LoadFile($config);

            if ( ref $item ne 'HASH' ) {
                die "the data is malformed\n";
            }

            try {
                $self->add_files($item);
            } catch {
                die "the data is malformed: $_\n";
            };

        } catch {
            die "Failed to load '$config': $_";
        };
    }

    return;
}

sub new_from_config {
    my ( $class, $config ) = @_;

    if ( !-f $config ) {
        die "Failed to load from '$config': file is not accessible\n";
    }

    my $self;
    try {
        require YAML::XS;
        local $YAML::XS::UseCode  = 0;
        local $YAML::XS::LoadCode = 0;

        my $data = YAML::XS::LoadFile($config);

        if ( ref $data ne 'HASH' ) {
            die "the data is malformed\n";
        }

        # Handle the list of files separately
        my $files = delete $data->{files};

        $self = $class->new($data);

        if ( defined $files ) {
            if ( ref $files eq 'ARRAY' ) {
                my $count = 0;
                for my $item (@{$files}) {
                    if ( !defined $item ) {
                        next;
                    }

                    try {
                        $self->add_files($item);
                    } catch {
                        if ( ref $item eq 'HASH' && exists $item->{id} ) {
                            die "files list item $count ($item->{id}) is malformed: $_\n";
                        } else {
                            die "files list item $count is malformed: $_\n";
                        }

                    };
                    $count++;
                }
            } else {
                die "the files data is malformed\n";
            }
        }

    } catch {
        die "Failed to load from '$config': $_";
    };

    return $self;

}

1;

package Xenon::FileBuilder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;

with 'Xenon::Role::Log4perl';

use Try::Tiny;
use Types::Standard qw(Str);
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

sub _build_files {
    return [];
}

sub BUILD {
    my ($self) = @_;

    if ( $self->has_registry && !$self->has_tag ) {
        die "Registry specified but no tag name given\n";
    }

}

sub add_file {
    my ( $self, $file_config ) = @_;

    my $file = XenonFileManager->coerce($file_config);

    my $files = $self->files;
    push @{$files}, $file;

    return;
}

sub configure {
    my ($self) = @_;

    my @files = @{ $self->files };

    my @changed_files;

    my %current_paths;
    for my $file (@files) {
        my $id = $file->id;

        # Whether we succeed or fail to configure the file we want to
        # push the path onto the list so that it doesn't get removed
        # or deregistered.

        $current_paths{$file->path} = $file;

        try {
            $self->logger->debug('Configuring ' . $id);

            my ($change_type) = $file->configure();
            if ( $change_type != $CHANGE_NONE ) {
                push @changed_files, $file->path;
            }

            if ( $self->has_registry ) {
                $self->registry->register_path(
                    $self->tag, $file->path, $file->permanent,
                );
            }

        } catch {
            $self->logger->error("Failed to configure file '$id': $_");
        };

        if ( $self->has_registry ) {
            my @registered_paths = $self->registry->paths_for_tag($self->tag);

            for my $path (@registered_paths) {
                if ( !$current_paths{$path->path} ) {
                    my $entry = $self->registry->get_entry_for_path($path);

                    if ( !$entry->{permanent} ) {
                        try {
                            if ( $path->is_dir ) {
                                if ( scalar $path->children > 0 ) {
                                    die "non-empty directory\n";
                                } else {
                                    rmdir $path or die "$!\n";
                                }
                            } else {
                                $path->remove or die "$!\n";
                            }
                        } catch {
                            $self->logger->error("Failed to remove path '$path': $_");
                        } finally {
                            $self->registry->deregister_path( $self->tag, $path );
                        };
                    }

                }
            }

        }

    }

    return @changed_files;

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
                $self->add_file($item);
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
                        $self->add_file($item);
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

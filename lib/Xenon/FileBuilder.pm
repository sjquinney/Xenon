package Xenon::FileBuilder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use Try::Tiny;
use Types::Path::Tiny qw(AbsPath);
use Xenon::Types qw(XenonFileManager XenonFileManagerList XenonRegistry);
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

    for my $file (@files) {
        my $id = $file->id;
        try {
            say STDERR 'Configuring ' . $id;
            $file->configure();

            if ( $self->has_registry ) {
                $self->registry->register_path(
                    $self->tag, $file->path, $file->permanent,
                );
            }
        } catch {
            warn "Failed to configure file '$id': $_\n"; 
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

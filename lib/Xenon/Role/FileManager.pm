package Xenon::Role::FileManager; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Readonly;
Readonly my $ID_UNCHANGED => -1;

use URI::Escape ();
use English qw(-no_match_vars);
use Try::Tiny;
use Types::Path::Tiny qw(AbsPath);
use Types::Standard qw(Bool Str);
use Xenon::Constants qw(:change);
use Xenon::Types qw(UID GID UnixMode XenonAttributeManagerList);

use Moo::Role;

with 'Xenon::Role::Log4perl';

requires 'path_type_is_correct', 'build', 'default_mode';

has 'id' => (
    is        => 'ro',
    isa       => Str,
    lazy      => 1,
    default   => sub { $_[0]->path->stringify },
);

has 'pathtype' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
    lazy     => 1,
    builder  => '_build_pathtype',
);

has 'path' => (
    is       => 'ro',
    isa      => AbsPath,
    coerce   => AbsPath->coercion,
    required => 1,
);

has 'source' => (
    is       => 'ro',
    isa      => AbsPath,
    coerce   => AbsPath->coercion,
    required => 1,
);

has 'owner' => (
    is        => 'ro',
    isa       => UID,
    coerce    => UID->coercion,
    predicate => 'has_owner',
);

has 'group' => (
    is        => 'ro',
    isa       => GID,
    coerce    => GID->coercion,
    predicate => 'has_group',
);

has 'mode' => (
    is        => 'ro',
    isa       => UnixMode,
    predicate => 'has_mode',
);

has 'attributes' => (
    is      => 'ro',
    isa     => XenonAttributeManagerList,
    coerce  => XenonAttributeManagerList->coercion,
    builder => '_build_attributes',
    lazy    => 1,
);

sub _build_attributes { [] }

has 'mkdir' => (
    is      => 'ro',
    isa     => Bool,
    default => sub { 0 },
);

has 'zap' => (
    is      => 'ro',
    isa     => Bool,
    default => sub { 0 },
);

has 'permanent' => (
    is      => 'ro',
    isa     => Bool,
    default => sub { 0 },
);

has 'dryrun' => (
    is      => 'rw',
    isa     => Bool,
    default => sub { 0 },
);

# Sensible default behaviour. Typically the class which implements
# this role will provide a local version of the method which just
# simply returns the correct path type.

sub _build_pathtype {
    my ($self) = @_;

    my $pathtype;
    if ( $self->path->is_file ) {
        if ( -l $self->path->path ) {
            $pathtype = 'link';
        } else {
            $pathtype = 'file';
        }
    } else {
        $pathtype = 'directory';
    }

    return $pathtype;
}

sub BUILDARGS {
  my ( $class, @args ) = @_;

  my %args;
  if ( scalar @args == 1 ) {
      %args = %{ $args[0] };
  } else {
      %args = @args;
  }

  # Support file names which have been URI escaped
  for my $key (qw/path source/) {
      if ( Str->check($args{$key}) ) {
          $args{$key} = URI::Escape::uri_unescape($args{$key});
      }
  }

  return \%args;
};

sub prebuild {
    my ($self) = @_;

    my $path = $self->path;
    if ( $path->exists ) {

        if ( $self->path_type_is_correct ) {
            $self->set_access_controls($self->path);
        } else {

            if ( $self->zap ) {
                if ( $path->is_dir ) {
                    try {

                        if ($self->dryrun) {
                            $self->logger->info("Dry-run: Will zap directory '$path' as it is not the correct path type");
                        } else {
                            $path->remove_tree( { safe => 0 } );
                        }

                    } catch {
                        die "Failed to remove directory '$path': $_\n";
                    };
                } else {

                    if ($self->dryrun) {
                        $self->logger->info("Dry-run: Will zap file '$path' as it is not the correct path type");
                    } else {
                        $path->remove or
                            die "Failed to remove file '$path': $_\n";
                    }

                }
            } else {
                die "Path '$path' already exists but is not the correct type and zap option is not enabled\n";
            }

        }

    } else {
        $self->check_parent();
    }

    return;
}

sub configure {
    my ( $self, @build_args ) = @_;

    $self->prebuild;

    my ($change_type) = $self->build(@build_args);

    my $file = $self->path;
    if ( $change_type == $CHANGE_CREATED ) {
        $self->logger->info("Successfully created '$file'");
    } elsif ( $change_type == $CHANGE_UPDATED ) {
        $self->logger->info("Successfully updated '$file'");
    }

    return $change_type;
}

sub check_parent {
    my ($self) = @_;

    my $logger = $self->logger;

    my $parent = $self->path->parent;
    $logger->debug("Checking existence of parent directory '$parent'");

    if ( !$parent->exists ) {
        if ( $self->mkdir ) {
            $logger->debug("Attempting to create parent directory '$parent'");
            try {

                if ($self->dryrun) {
                    $logger->info("Dry-run: Will create parent directory '$parent'");
                } else {
                    $parent->mkpath;
                }

            } catch {
                die "Failed to create parent directory '$parent': $_\n";
            };
        } else {
            die "Parent directory '$parent' does not exist and mkdir option is not enabled\n";
        }
    } elsif ( !$parent->is_dir ) {
        die "'$parent' is not a directory, cannot create child files\n";
    }

    return;
}

sub required_mode {
    my ($self) = @_;

    my $required_mode;
    if ( $self->has_mode ) {
        $required_mode = $self->mode;
        $self->logger->debug(sprintf 'Using specific mode 0%o', $required_mode );
    } else {

        # If nothing is specified then we use the current mode if
        # there is one, otherwise just use the default.

        if ( $self->path->exists ) {
            $required_mode = $self->path->stat->mode & oct('07777');
            $self->logger->debug(sprintf 'Using current mode 0%o', $required_mode );
        } else {
            $required_mode = $self->default_mode;

            # Honour the umask which might tighten the mode settings

            my $umask = umask;
            $required_mode &= ~$umask;

            $self->logger->debug(sprintf 'Using default mode 0%o', $required_mode );
        }

    }

    return $required_mode;
}

sub set_access_controls {
    my ( $self, $path ) = @_;

    if ( !defined $path ) {
        $path = $self->path;
    } else {
        # ensure we have a Path::Tiny object
        $path = AbsPath->coerce($path);
    }

    my $stat = $path->stat;

    if ( $EUID == 0 ) { # Only root can change owner:group

        my $new_owner = $ID_UNCHANGED;
        if ( $self->has_owner && $self->owner != $stat->uid ) {
            $new_owner = $stat->uid;
        }

        my $new_group = $ID_UNCHANGED;
        if ( $self->has_group && $self->group != $stat->gid ) {
            $new_group = $stat->gid;
        }

        if ( $new_owner != $ID_UNCHANGED || $new_group != $ID_UNCHANGED ) {

            if ( $self->dryrun ) {
                $self->logger->info("Dry-run: Will chown $new_owner:$new_group '$path'");
            } else {
                $self->logger->debug("chown $new_owner:$new_group $path");
                chown $new_owner, $new_group, "$path"
                    or die "Could not chown $new_owner:$new_group '$path': $OS_ERROR\n";
            }

        }
    }

    my $required_mode = $self->required_mode;
    my $current_mode  = $stat->mode & oct('07777'); # Remove the file type part

    if ( $current_mode != $required_mode ) {

        if ( $self->dryrun ) {
            $self->logger->info(sprintf 'Dry-run: Will chmod 0%o \'%s\'', $required_mode, $path );
        } else {
            $self->logger->debug(sprintf 'Current mode: 0%o, required mode: 0%o', $current_mode, $required_mode );

            $path->chmod($required_mode)
                or die "Could not chmod $required_mode '$path': $OS_ERROR\n";
        }

    }

    for my $attr_mgr (@{ $self->attributes }) {
        # Map in the current setting for the dryrun attribute
        $attr_mgr->dryrun($self->dryrun);

        $attr_mgr->configure($path);
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

        $self = $class->new($data);
    } catch {
        die "Failed to load from '$config': $_";
    };

    return $self;
}

1;

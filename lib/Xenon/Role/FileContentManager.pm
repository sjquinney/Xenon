package Xenon::Role::FileContentManager; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Readonly;
Readonly my $NOCHANGE      = 0;
Readonly my $CHANGE_NEW    = 1;
Readonly my $CHANGE_UPDATE = 2;

use Digest ();
use English qw(-no_match_vars);
use File::Temp ();
use Types::Standard qw(HashRef Str);
use Xenon::Types qw(XenonResource XenonBackupStyle XenonContentDecoderList);
use Try::Tiny;

use Moo::Role;

with 'Xenon::Role::FileManager';

requires 'build_data', 'default_options';

# Replaces the standard source with a URI-type
has '+source' => (
    is       => 'ro',
    isa      => XenonResource,
    coerce   => XenonResource->coercion,
    required => 1,
);

has 'encoding' => (
    is      => 'ro',
    isa     => XenonContentDecoderList,
    coerce  => XenonContentDecoderList->coercion,
    builder => '_build_encoding',
    lazy    => 1,
);

sub _build_encoding { [] }

has 'digest_algorithm' => (
    is      => 'ro',
    isa     => Str,
    default => sub { 'SHA-256' },
);

has 'backup_style' => (
    is      => 'ro',
    isa     => XenonBackupStyle,
    default => sub { 'tilde' },
);

has 'options' => (
    is      => 'ro',
    isa     => HashRef,
    builder => '_build_options',
    lazy    => 1,
);

sub _build_options {
    return {};
}

around 'default_options' => sub {
    my ( $orig, $class, %new_config ) = @_;

    state $config = $orig->($class);

    if ( scalar keys %new_config > 0 ) {
        $config = { %{$config}, %new_config };
    }

    if (wantarray) {
        return %{$config};
    }

};

sub merge_options {
    my ($self) = @_;

    my %default_options = $self->default_options;
    my %options = ( %default_options, %{ $self->options } );

    return %options;
}

sub default_mode {
    return oct('0644');
}

sub path_type_is_correct {
    my $self = shift @_;

    return ( $self->path->is_file && !-l $self->path ) ? 1 : 0;
}

sub content_needs_update {
    my ( $self, $new_digest ) = @_;

    my $path = $self->path;

    my $needs_update = $CHANGE_NEW;
    if ( $path->exists ) {

        my $cur_digest = $path->digest($self->digest_algorithm);

        if ( $new_digest eq $cur_digest ) {
            $needs_update = $NOCHANGE;
        } else {
            $needs_update = $CHANGE_UPDATE;
        }

    }

    return $needs_update;
}

sub digest_data {
    my ( $self, $data ) = @_;

    my $ctx = Digest->new($self->digest_algorithm);
    $ctx->add($data);
    my $digest = $ctx->hexdigest();

    return $digest;
}

sub build {
    my ($self) = @_;

    my $input = $self->source->fetch();

    for my $enc_type (@{ $self->encoding }) {
        $input = $enc_type->decode($input);
    }

    my $data   = $self->build_data($input);
    my $digest = $self->digest_data($data);

    my $needs_update = $self->content_needs_update($digest);
    if ( $needs_update != $NOCHANGE ) {
        say STDERR "Content needs update";

        my $path = $self->path;

        # Rather than using spew() we do this manually so that we can
        # set the correct access controls on the new file and make the
        # backup before we do the rename. Thus the final stage of
        # doing the rename only happens if everything else has
        # succeeded.

        try {
            my $tmpfh = File::Temp->new( TEMPLATE => 'xenonXXXXXX',
                                         DIR      => $path->dirname,
                                         UNLINK   => 1 )
                or die "Could not open temporary file: $OS_ERROR\n";

            my $tempname = $tmpfh->filename;

            $tmpfh->print($data)
                or die "Could not write to temporary file: $OS_ERROR\n";
            $tmpfh->close()
                or die "Could not close temporary file: $OS_ERROR\n";

            $self->set_access_controls($tempname);

            $self->make_backup();
            
            if ( !rename $tempname, "$path" ) {
                die "Could not rename temporary file: $OS_ERROR\n";
            }

        } catch {
            die "Failed to update '$path': $_";
        };

    }

    return ( $needs_update, $digest );
}

sub make_backup {
    my ($self) = @_;

    my $path = $self->path;

    if ( !$path->exists ) {
        return;
    }

    my $style = $self->backup_style;
    if ( $style ne 'none' ) {

        my $suffix;
        if ( $style eq 'epochtime' ) {
            $suffix = q{.} . time;
        } else {
            $suffix = q{~};
        }
        my $backup_file = $path . $suffix;

        # We use a hard link so that the backup file really is the
        # current file. This avoids the potential for permissions to
        # get messed up when doing a copy.

        try {
            if ( -e $backup_file ) {
                unlink $backup_file
                    or die "Cannot remove old file: $OS_ERROR\n";
            }

            link "$path", $backup_file
                or die "Cannot make hard link: $OS_ERROR\n";
        } catch {
            die "Failed to make backup file '$backup_file' for '$path': $_";
        };

    }

    return;
}

1;

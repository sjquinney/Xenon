package Xenon::Role::Backup; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;
use Try::Tiny;
use Xenon::Types qw(XenonBackupStyle);

has 'backup_style' => (
    is      => 'ro',
    isa     => XenonBackupStyle,
    default => sub { 'tilde' },
);

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


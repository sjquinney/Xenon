package Xenon::Role::Backup; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use English qw(-no_match_vars);
use File::Temp ();
use Try::Tiny;
use Types::Path::Tiny qw(AbsPath);
use Xenon::Types qw(XenonBackupStyle);

use Moo::Role;

has 'backup_style' => (
    is      => 'ro',
    isa     => XenonBackupStyle,
    default => sub { 'tilde' },
);

sub make_backup {
    my ( $self, $path ) = @_;

    if ( !defined $path ) {
        $path = $self->path;
    } else {
        # ensure we have a Path::Tiny object
        $path = AbsPath->coerce($path);
    }

    if ( !$path->exists ) {
        return;
    }

    # Only make backup copies of files

    if ( $path->is_dir || -l $path->stringify ) {
        return;
    }

    my $copy_made = 0;

    my $style = $self->backup_style;
    if ( $style eq 'none' ) {
        return $copy_made;
    }

    # Select the required backup file name

    my $suffix;
    if ( $style eq 'epochtime' ) {
        $suffix = q{.} . time;
    } else {
        $suffix = q{~};
    }

    my $backup_file = AbsPath->coerce($path . $suffix);

    # Check if we actually need to make a new backup

    if ( $backup_file->exists ) {
        if ( $path->digest('SHA-256') eq $backup_file->digest('SHA-256') ) {
            return $copy_made;
        }
    }

    my $umask = umask oct('0077');

    try {

        my $tmpfh = File::Temp->new( TEMPLATE => 'xenonXXXXXX',
                                     DIR      => $path->parent,
                                     UNLINK   => 1 )
            or die "Could not open temporary file: $OS_ERROR\n";

        my $tmpfile = $tmpfh->filename;

        my $infh = $path->openr();
        while (defined( my $line = $infh->getline ) ) {
            $tmpfh->print($line)
                or die "Could not write temporary file '$tmpfile': $OS_ERROR\n";
        }

        $tmpfh->close()
            or die "Could not close temporary file '$tmpfile': $OS_ERROR\n";

        my $stat = $path->stat;

        my $required_mode = $stat->mode & oct('07777');
        chmod $required_mode, $tmpfile
            or die sprintf( "Could not chmod temporary file '%s' 0%o: %s\n",
                            $tmpfile, $required_mode, $OS_ERROR );

        my $required_uid = $stat->uid;
        my $required_gid = $stat->gid;
        my ( $current_uid, $current_gid ) = (stat $tmpfile)[4,5];

        if ( $required_uid != $current_uid ||
             $required_gid != $current_gid ) {

            chown $required_uid, $required_gid, $tmpfile
                or die "Could not chown temporary file '$tmpfile' $required_uid:$required_gid: $OS_ERROR\n";

        }

        utime $stat->atime, $stat->mtime, $tmpfile;

        if ( -e $backup_file ) {
            unlink $backup_file
                or die "Could not remove previous version: $OS_ERROR\n";
        }

        rename $tmpfile, $backup_file
            or die "Could not rename '$tmpfile': $OS_ERROR\n";

        $copy_made = 1;

    } catch {
        die "Failed to make backup file '$backup_file' for '$path': $_";
    } finally {
        umask $umask;
    };

    return $copy_made;
}

1;
__END__

=head1 NAME

Xenon::Role::Backup - A Moo role which supports creating file backups

=head1 VERSION

This documentation refers to Xenon::Role::Backup version 1.0.0

=head1 SYNOPSIS

  package Xenon::File::Foo;

  use Moo;
  with 'Xenon::Role::Backup';


  package main;

  use Xenon::File::Foo;

  my $foo = Xenon::File::Foo->new( backup_style => "tilde" );
  $foo->make_backup("/tmp/example.txt");

  # Backup copy is now /tmp/example.txt~

=head1 DESCRIPTION

This is a Moo role which adds simple support for creating backup
copies of files. The role supports creating backup copies of files
with names which match various "styles". The role can be consumed by
any Moo or Moose class.

=head1 ATTRIBUTES

This role adds one attribute to a class:

=over

=item backup_style

This is the style of backup file which should be created. The
following options are supported: C<tilde>, C<epochtime> and C<none>,
the default is C<tilde>.

If the style is set to C<tilde> then the name of the backup file will
be the name of the file specified with a C<~> suffix. If the style is
set to C<epochtime> then the file will have a suffix which is the time
in seconds since the epoch. If the style is set to C<none> then no
backup will be created.

=back

=head1 SUBROUTINES/METHODS

This role adds one method to a class:

=over

=item make_backup($path)

If the path exists and it is a file (i.e. not a directory or symlink)
then a backup copy will be made. The name of the backup file is
dependent upon the setting of the C<backup_style> attribute, see above
for details.

The backup preserves the owner, group, mode and timestamps. Note that
other attributes such as ACLs and xattr will NOT be preserved. That
must be handled separately if it is required.

Any file with the same name as the backup file will be deleted before
the backup copy is created.

If a problem occurs this method will die with a useful error message.

=back

=head1 DEPENDENCIES

This module is powered by L<Moo>. Files are handled using
L<Path::Tiny> which is loaded via the L<Types::Path::Tiny> module. The
L<Try::Tiny> module is also required.

=head1 SEE ALSO

L<Xenon>

=head1 PLATFORMS

We expect this software to work on any Unix-like platform which is
supported by Perl.

=head1 BUGS AND LIMITATIONS

Please report any bugs or problems (or praise!) to the author,
feedback and patches are also always very welcome.

=head1 AUTHOR

Stephen Quinney <squinney@inf.ed.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Stephen Quinney. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL, version 2 or later.

=cut

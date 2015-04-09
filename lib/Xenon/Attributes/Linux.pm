package Xenon::Attributes::Linux; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo;
use Types::Standard qw(ArrayRef HashRef Str);
use Xenon::Types qw(UID GID);

with 'Xenon::Role::AttributeManager';

use namespace::clean;

has 'acls' => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

has 'default_acls' => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

sub split_perms {
    my ($perms_str) = @_;

    my $perms_hash = { r => 0, w => 0, x => 0 };

    if ( defined $perms_str ) {
        for my $perm ( qw/r w x/ ) {
            $perms_hash->{$perm} = index( $perms_str, $perm ) == -1 ? 0 : 1;
        }
    }

    return $perms_hash;
}

sub parse_acls {
    my @entries = @_;

    my %acls;
    my %default_acls;

    for my $entry (@entries) {
        for my $acl_orig ( split /[\s,]+/, $entry ) {

            my $store;

            my $acl = $acl_orig;
            if ( $acl =~ s/^d(efault)?:// ) {
                $store = \%default_acls;
            } else {
                $store = \%acls;
            }

            my ( $class, $class_name, $class_perms ) = split /:/, $acl;
            $class_perms = split_perms($class_perms);

            if ( $class =~ m/^u(ser)?$/i ) {
                if ( !defined $class_name || $class_name !~ m/\S/ ) {
                    $store->{uperm} = $class_perms;
                } else {
                    if ( !UID->check($class_name) ) {
                        $class_name = UID->coerce($class_name);
                        UID->check($class_name) or
                            die "Invalid user '$class_name'\n";
                    }

                    $store->{user}{$class_name} = $class_perms;
                }
            } elsif ( $class =~ m/^g(roup)?$/i ) {
                if ( !defined $class_name || $class_name !~ m/\S/ ) {
                    $store->{gperm} = $class_perms;
                } else {
                    if ( !GID->check($class_name) ) {
                        $class_name = GID->coerce($class_name);
                        GID->check($class_name) or
                            die "Invalid group '$class_name'\n";
                    }

                    $store->{group}{$class_name} = $class_perms;
                }

            } elsif ( $class =~ m/^o(ther)?$/i ) {
                $store->{other} = $class_perms;
            } elsif ( $class =~ m/^m(ask)?$/i ) {
                $store->{mask} = $class_perms;
            } else {
                die "Failed to parse '$acl_orig'\n";
            }
        }

    }

    return ( \%acls, \%default_acls );
}

sub BUILDARGS {
  my ( $class, @args ) = @_;

  my %args;
  if ( scalar @args == 1 ) {
      if ( Str->check($args[0]) ) {
          ( $args{acls}, $args{default_acls} ) = parse_acls($args[0]);
      } elsif ( ArrayRef->check($args[0]) ) {
          ( $args{acls}, $args{default_acls} ) = parse_acls(@{ $args[0] });
      }
  } else {
      %args = @args;
  }

  return \%args;
};

sub automask {
    my ($acls) = @_;

    # This is modelled on the behaviour of the setfacl command. The
    # manual page says:
    #
    # """The default behavior of setfacl is to recalculate the ACL
    # mask entry, unless a mask entry was explicitly given.  The mask
    # entry is set to the union of all permissions of the owning
    # group, and all named user and group entries.  (These are exactly
    # the entries affected by the mask entry)."""

    my $automask = { r => 0, w => 0, x => 0 };

    PERM: for my $perm (qw/r w x/) {

        # union of group and named user and named group perms

        if ( $acls->{gperm}{$perm} ) {
            $automask->{$perm} = 1;
            next PERM;
        }

        if ( $acls->{user} ) {
            for my $user (keys %{$acls->{user}}) {
                if ( $acls->{user}{$user}{$perm} ) {
                    $automask->{$perm} = 1;
                    next PERM;
                }
            }
        }
        if ( $acls->{group} ) {
            for my $group (keys %{$acls->{group}}) {
                if ( $acls->{group}{$group}{$perm} ) {
                    $automask->{$perm} = 1;
                    next PERM;
                }
            }
        }

    }

    return $automask;
}

sub merge_with_current {
    my ( $new, $current ) = @_;

    my $merged = \%{ $new };

    # Copy through the basic user, group and other perms unless they
    # are specified. This ensures we do not unintentionally blow away
    # the mode which was already set elsewhere.

    for my $class (qw/uperm gperm other/) {
        $merged->{$class} //= $current->{$class};
    }

    for my $class (qw/user group/) {
        $merged->{$class} //= {};
    }

    # We also need to ensure we have a sensible mask otherwise it will
    # end up being set as '---' which is applied to any user and group
    # settings and makes them useless.

    $merged->{mask} //= automask($merged);

    return $merged;
}

sub hashes_differ {
    my ( $hash_a, $hash_b ) = @_;

    # Canonical ensures the hashes are sorted on keys
    require JSON;

    my $json_a = JSON->new->canonical(1)->encode($hash_a);
    my $json_b = JSON->new->canonical(1)->encode($hash_b);

    my $differ = $json_a eq $json_b ? 0 : 1;

    return $differ;
}

sub configure {
    my ( $self, $path ) = @_;

    if ( !-e $path ) {
        die "Path '$path' does not exist\n";
    }

    require Linux::ACL;

    # Only directories have 'default' ACLs

    my ( $current_acls, $current_default_acls ) = Linux::ACL::getfacl($path);

    my $merged_acls = merge_with_current( $self->acls, $current_acls );
    my @setfacl_args = ( $merged_acls );

    my $needs_update = hashes_differ( $current_acls, $merged_acls );

    if ( -d $path ) {

        # Only apply 'default' ACLs when they are specified

        if ( scalar keys %{$self->default_acls} > 0 ) {
            my $merged_default_acls =
                merge_with_current( $self->default_acls, $current_default_acls );
            push @setfacl_args, $merged_default_acls;

            $needs_update ||= hashes_differ( $current_default_acls,
                                             $merged_default_acls );

        }

    }

    if ($needs_update) {
        $self->logger->info("Need to update Linux ACLs for '$path'");

        if ( $self->dryrun ) {
           $self->logger->info("Dry-run: Will update Linux ACLs for '$path'");
        } else {
            Linux::ACL::setfacl( $path, @setfacl_args )
                or die "Failed to set Linux ACLs on '$path'\n";
            $self->logger->info("Successfully set Linux ACLs on '$path'");
        }

    }

    return;
}

1;
__END__

=head1 NAME

Xenon::Attributes::Linux - Manage Linux file and directory ACLs

=head1 VERSION

This documentation refers to Xenon::Attributes::Linux version v1.0.0

=head1 SYNOPSIS

  use Xenon::Attribute::Linux;

  my $attr = Xenon::Attribute::Linux->new('group:foo:rw', 'user:fred:r');

  $attr->configure('/tmp/example.txt');

=head1 DESCRIPTION

This class implements the L<Xenon::Role::AttributeManager> role for
managing Linux ACLs on files and directories. It aims to make the
experience as simple as using setfacl(1) on the command line.

Note that your filesystem must be mounted with ACL support enabled for
this tool to be able to configure ACLs!

=head1 ATTRIBUTES

=over

=item acls

This attribute holds a reference to a hash which represents the
required state of the ACLs for the file or directory. This is used by
L<Linux::ACL>, see the documentation of that module for full
details. The permitted keys are:

=over

=item C<uperm>

ACLs for the primary user. If this is not specified then the current
setting will be used.

=item C<gperm>

ACLs for the primary group. If this is not specified then the current
setting will be used.

=item C<other>

ACLs for all others. If this is not specified then the current setting
will be used.

=item C<mask>

A permissions mask which applies to the primary group, and all named
users and groups. Typically this is automatically calculated to be the
union of all permissions of the owning group, and all named user and
group entries.

=item C<user>

ACLs for named users (can be user names or numeric IDs). If a named
user does not exist then the GID lookup will throw an exception. If
nothing is specified then any current ACLs for named users will be
removed.

=item C<group>

ACLs for named groups (can be group names or numeric IDs). If a named
group does not exist then the GID lookup will throw an exception. If
nothing is specified then any current ACLs for named groups will be
removed.

=back

ACLs are specified via a reference to a hash with keys C<r>, C<w>,
C<x> where each value can be 1 (one) or 0 (zero) to enable or
disable. For example:

  {
      uperm => { r=>1, w=>1, x=>1 },
      gperm => { r=>1, w=>1, x=>1 },
      other => { r=>1, w=>0, x=>1 },
      mask  => { r=>1, w=>1, x=>1 },
      group => {
              123456 => { r=>1, w=>1, x=>1 },
      },
  }

To avoid having to specify a complex hash for the C<acls> attribute,
the C<new> method can handle a list of simpler ACL strings in a
similar way to setfacl(1), see the documentation below for that method
for details.

=item default_acls

These are 'default' ACLs which can be attached to directories and are
then applied to any new files created within that directory. The ACLs
are specified in the same way as described for the C<acls> attribute
above. Anything specified in the C<default_acls> attribute is silently
ignored for files.

To avoid having to specify a complex hash for the C<default_acls>
attribute, the C<new> method can handle a list of simpler ACL strings
in a similar way to setfacl(1), see the documentation below for that
method for details.

=item dryrun

This is a boolean attribute which indicates whether or not to actually
apply any necessary changes. The default value is C<false>. When the
setting is C<true> the C<configure> method will log what would have
been done with a C<Dry-run:> prefix.

=item debug

This attribute is used to control the logging level. It can be
modified via the C<set_debug>, C<enable_debug> or C<disable_debug>
methods. This attribute is inherited from the L<Xenon::Role::Log4perl>
role.

=item logger

This attribute holds the Log4perl logger instance. This attribute is
inherited from the L<Xenon::Role::Log4perl> role.

=item logconf

This attribute holds the Log4perl logger configuration. Log4perl uses
a singleton object so this will only be used if the logger instance
has not already been initialised. This attribute is inherited from the
L<Xenon::Role::Log4perl> role.

=back

=head1 SUBROUTINES/METHODS

=over

=item new(@acls)

This can be used to create a new L<Xenon::Attributes::Linux> instance.

A list of ACL strings can be specified which conform to the format
described in the setfacl(1) documentation.

=over

=item [d[efault]:] [u[ser]:]uid [:perms]

Permissions of a named user. Permissions of the file owner if uid is
empty.

=item [d[efault]:] g[roup]:gid [:perms]

Permissions of a named group. Permissions of the owning group if gid
is empty.

=item [d[efault]:] m[ask][:] [:perms]

Effective rights mask

=item [d[efault]:] o[ther][:] [:perms]

Permissions of others.

=back

For example: C<g:people:r>, C<u:fred:rw>, C<d:g:people:r>

=item new_from_json( $json, @overrides )

This role imports the L<Xenon::Role::ConfigFromJSON> role which adds a
C<new_from_json> method. This can be used to create a new instance
with the option to specify attributes as a JSON file or string. See
the documentation for that role for more details.

=item configure($path)

This compares the current ACLs for the specified file or directory
with those specified in the C<acls> and C<default_acls> attributes. If
any changes are required they are applied using the L<setfacl>
function in the L<Linux::ACL> module.

To avoid clashing with the support built-in to Xenon for managing the
owner, group and mode of a file it is recommended that you do not use
this module to change those attributes. If those attributes are not
specified then they will be preserved when changes are applied.

It is also advisable to avoid changing the mask unless it really is
essential. The automatically calculated value will normally be
adequate.

This method will die if the changes could not be applied. This might
happen if the filesystem is not mounted with ACL support.

If the C<dryrun> attribute is set to true then this method will only
log that changes were required.

=item enable_debug()

Turns the logging level up to DEBUG. This method is inherited from the
L<Xenon::Role::Log4perl> role.

=item disable_debug()

If the logging level had been previously raised to DEBUG then this
reverts the logging level. Alternatively if there is no previous
setting then it reduces the log level to INFO. This method is
inherited from the L<Xenon::Role::Log4perl> role.

=item set_debug($on_or_off)

Sets the value of the C<debug> attribute to be either true (1, one) or
false (0, zero). Setting the debug attribute to true will raise the
logging level to DEBUG. Setting the debug attribute to false will
restore or lower the level as described above. This method is
inherited from the L<Xenon::Role::Log4perl> role.

=head1 DEPENDENCIES

This module is powered by L<Moo>. This class implements the
L<Xenon::Role::AttributeManager> role. Consequently the
L<Xenon::Role::ConfigFromJSON> role is consumed, to use that role the
L<JSON> module must be available. It also consumes the
L<Xenon::Role::Log4perl> role for which the L<Log::Log4perl> module
must be installed.

The <Linux::ACL> module is used to actually apply the required ACLs,
it will be loaded when necessary. The serialisation functionality of
the L<JSON> module is used internally to assist with comparing deep
hash structures, it will be loaded when necessary.

=head1 SEE ALSO

L<Xenon>, getfacl(1), setfacl(1)

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

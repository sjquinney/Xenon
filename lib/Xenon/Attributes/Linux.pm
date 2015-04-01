package Xenon::Attributes::Linux; # -*- perl -*-
use strict;
use warnings;

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
                if ( !defined $class_name || length $class_name == 0 ) {
                    $store->{uperm} = $class_perms;
                } else {
                    if ( !UID->check($class_name) ) {
                        $class_name = UID->coerce($class_name);
                    }

                    $store->{user}{$class_name} = $class_perms;
                }
            } elsif ( $class =~ m/^g(roup)?$/i ) {
                if ( !defined $class_name || length $class_name == 0 ) {
                    $store->{gperm} = $class_perms;
                } else {
                    if ( !GID->check($class_name) ) {
                        $class_name = GID->coerce($class_name);
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

    # We also need to ensure we have a sensible mask otherwise it will
    # end up being set as '---' which is applied to any user and group
    # settings and makes them useless.

    $merged->{mask} //= automask($merged);

    return $merged;
}

sub configure {
    my ( $self, $path ) = @_;

    if ( !-e $path ) {
        die "Path '$path' does not exist\n";
    }

    require Linux::ACL;

    # Only directories have 'default' ACLs

    if ( -d $path ) {
        my ( $current_acls, $current_default_acls ) = 
            Linux::ACL::getfacl($path);

        my $merged_acls =
            merge_with_current( $self->acls, $current_acls );

        # Only apply 'default' ACLs when they are specified

        if ( scalar keys %{$self->default_acls} > 0 ) {
            my $merged_default_acls =
                merge_with_current( $self->default_acls, $current_default_acls );
            Linux::ACL::setfacl( $path, $merged_acls, $merged_default_acls )
                or die "Failed to setfacl on '$path'\n";

        } else {
            Linux::ACL::setfacl( $path, $merged_acls )
                or die "Failed to setfacl on '$path'\n";
        }


    } else {
        my ($current_acls) = 
            Linux::ACL::getfacl($path);

        my $merged_acls =
            merge_with_current( $self->acls, $current_acls );

        Linux::ACL::setfacl( $path, $merged_acls )
            or die "Failed to setfacl on '$path'\n";
    }

    return
}

1;

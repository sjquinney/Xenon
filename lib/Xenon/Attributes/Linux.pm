package Xenon::Attributes::Linux; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use JSON ();

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

package Xenon::Role::Registry; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Types::Path::Tiny qw(AbsPath);

use Moo::Role;

with 'Xenon::Role::Log4perl';

requires 'can_register_path', 'deregister_path', 'can_register_path',
    'path_is_registered', 'paths_for_tag', 'register_path';

sub path_metadata {
    my ( $self, $path, $meta_ref ) = @_;
    $meta_ref = {};

    my %meta = %{$meta_ref}; # Avoiding messing with the original

    $path = AbsPath->coerce($path);

    if ( !$path->exists ) {
        return;
    }

    if ( !defined $meta{pathtype} ) {
        if ( $path->is_file ) {
            if ( -l $path->path ) {
                $meta{pathtype} = 'link';
            } else {
                $meta{pathtype} = 'file';
            }
        } else {
            $meta{pathtype} = 'directory';
        }
    }

    if ( $meta{pathtype} eq 'file' ) {
        if ( !defined $meta{digest} ) {
            $meta{digest} = $path->digest('SHA-256');
            $meta{digest_algorithm} = 'SHA-256';
        }
    } else {
        delete $meta{digest};
    }

    my $stat = $path->stat;
    $meta{mode}  //= $stat->mode & 07777;
    $meta{uid}   //= $stat->uid;
    $meta{gid}   //= $stat->gid;
    $meta{mtime} //= $stat->mtime;

    return %meta;
}

1;
 

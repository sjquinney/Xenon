package Xenon::TypeUtils; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Module::Find ();
use UNIVERSAL::require;

sub find_role_module {
    my ( $name, $modbase ) = @_;

    # Stash the lookups to save time/effort
    state $file_managers = {};
    if (!defined $file_managers->{$modbase}) {
        $file_managers->{$modbase} = {};

        my @file_manager_modules = Module::Find::findsubmod($modbase);
        for my $mod (@file_manager_modules) {
            my $fm = lc $mod;
            $fm =~ s/^\Q$modbase\E:://i;
            $file_managers->{$modbase}{$fm} = $mod;
        }
    }

    my $fm;
    if ( $name =~ m/^\Q$modbase\E::.+$/ ) {
        $fm = $name;
    } else {
        $fm = $file_managers->{$modbase}{lc $name};
    }

    say STDERR "$name --> $fm";
    if ( !defined $fm ) {
        die "Failed to find module for '$name' in '$modbase' namespace\n";
    }

    return $fm;
}

sub load_role_module {
    my ( $name, $modbase ) = @_;

    my $mod = find_role_module( $name, $modbase );
    $mod->require
        or die "Failed to load content-decoder module '$mod': $@\n";

    return $mod;
}

1;

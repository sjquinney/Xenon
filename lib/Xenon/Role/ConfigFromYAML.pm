package Xenon::Role::ConfigFromYAML; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Types::Standard qw(ScalarRef HashRef ArrayRef);
use Try::Tiny;

use Moo::Role;

sub new_from_yaml {
    my ( $class, $yaml, @overrides ) = @_;

    # Defaults to a scalar reference to the string '--- {}', i.e. an empty hash
    $yaml //= \ q(--- {});

    my %args;
    try {
        require YAML::XS;
        local $YAML::XS::UseCode  = 0;
        local $YAML::XS::LoadCode = 0;

        my $args;
        if ( ScalarRef->check($yaml) ) {
            $args = YAML::XS::Load(${$yaml});
        } else {
            if ( !-f $yaml ) {
                die "file is not accessible\n";
            }

            $args = YAML::XS::LoadFile($yaml);
        }

        if ( HashRef->check($args) ) {
            %args = %{ $args };
        } elsif ( ArrayRef->check($args) ) {
            %args = @{ $args };
        } else {
            die "malformed data\n";
        }

    } catch {
        die "Failed to load from '$config': $_";
    };

    if ( scalar @overrides == 1 && HashRef->check($overrides[0]) ) {
        %args = ( %args, %{$overrides[0]} );
    } else {
        %args = ( %args, @overrides );
    }

    return $class->new(%args);
}

1;

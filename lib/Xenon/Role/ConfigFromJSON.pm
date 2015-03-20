package Xenon::Role::ConfigFromJSON; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;
use Types::Path::Tiny qw(AbsPath);
use Types::Standard qw(ScalarRef HashRef ArrayRef);
use Try::Tiny;

sub new_from_json {
    my ( $class, $json, @overrides ) = @_;

    # Defaults to a scalar reference to the string '{}', i.e. an empty hash
    $json //= \q({});

    require JSON;

    my $data;
    if ( ScalarRef->check($json) ) {
        $data = ${$json};
    } else {
        try {
            my $file = AbsPath->coerce($json);

            if ( !AbsPath->check($file) ) {
                die "invalid file name '$json'\n";
            }

            if ( !$file->is_file ) {
                die "does not exist\n";
            }

            $data = $file->slurp;
        } catch {
            die "Cannot load JSON from '$json': $_";
        };

    }

    my %args;
    try {
        my $args = JSON->new->relaxed(1)->decode($data);

        if ( HashRef->check($args) ) {
            %args = %{ $args };
        } elsif ( ArrayRef->check($args) ) {
            %args = @{ $args };
        } else {
            die "malformed data\n";
        }
    } catch {
        die "Failed to decode JSON data: $_";
    };

    if ( scalar @overrides == 1 && HashRef->check($overrides[0]) ) {
        %args = ( %args, %{$overrides[0]} );
    } else {
        %args = ( %args, @overrides );
    }

    return $class->new(%args);
}

1;


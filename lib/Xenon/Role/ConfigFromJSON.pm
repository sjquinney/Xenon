package Xenon::Role::ConfigFromJSON; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Types::Path::Tiny qw(AbsPath);
use Types::Standard qw(ScalarRef HashRef ArrayRef);
use Try::Tiny;

use Moo::Role;

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

=head1 NAME

Xenon::Role::ConfigFromJSON - A Moo role to load class attributes from JSON

=head1 VERSION

This documentation refers to Xenon::Role::ConfigFromJSON version 1.0.0

=head1 SYNOPSIS

  {
    package Xenon::Test;

    use Moo;
    use Types::Standard qw(Str);
    with 'Xenon::Role::ConfigFromJSON';

    has 'foo' => (
       is  => 'ro',
       isa => Str,
    );

  }

  # Load inline JSON data (note scalar reference)
  my $test1 = Xenon::Test->new_from_json( \ '{"foo":"bar"}' );

  # Load JSON data from file
  my $test2 = Xenon::Test->new_from_json('/tmp/test2.json');

  # Load JSON data from Path::Tiny file
  use Path::Tiny;
  my $path = path("/tmp/test3.json");
  my $test3 = Xenon::Test->new_from_json($path);


=head1 DESCRIPTION

This is a Moo role which adds support for loading the configuration
for a class (i.e. the values of the attributes) from JSON data. The
data can be either inline as a string or stored in a file.

=head1 ATTRIBUTES

This role does not add any attributes to the consuming class.

=head1 SUBROUTINES/METHODS

This role adds one method to the consuming class:

=over

=item new_from_json( $json, @overrides )

This can be used to create a new instance of the implementing class
with the option to specify attributes as a JSON file or string. If it
is a reference to a scalar then it is considered to be inline JSON
data otherwise an attempt will be made to coerce it into a
L<Path::Tiny> object via the L<Types::Path::Tiny> module.

It is expected that the JSON data will be loadable as a reference to a
hash or array of key and value pairs which are passed to the standard
C<new> method.

It is possible to override the settings in the JSON by passing in a
list of key, value pairs.

This method will load the L<JSON> module if necessary.

=back

=head1 DEPENDENCIES

This module is powered by L<Moo>. The L<Types::Path::Tiny> module (and
thus also L<Path::Tiny>) is used to handle paths to JSON files. The
L<JSON> module is required, it will not be loaded until necessary, for
speed you probably want L<JSON::XS> to be installed. The L<Try::Tiny>
module is used to catch exceptions.

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

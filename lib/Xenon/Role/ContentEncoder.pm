package Xenon::Role::ContentEncoder; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo::Role;

with 'Xenon::Role::ConfigFromJSON';

requires 'encode';

1;
__END__

=head1 NAME

Xenon::Role::ContentEncoder - A Moo role which defines a content encoder

=head1 VERSION

This documentation refers to Xenon::Role::ContentEncoder version 1.0.0

=head1 SYNOPSIS

   {
     package Xenon::Encoding::Rot13;

     use Moo;
     with 'Xenon::Role::ContentEncoder';

     sub encode {
        my ( $self, $in ) = @_;
        my $out = $in;
        $out =~ tr/A-Za-z/N-ZA-Mn-za-m/;
        return $out;
     }
   }

   my $encoder = Xenon::Encoding::Rot13->new();

   print $decoder->encode("hello world") . "\n";

=head1 DESCRIPTION

This is a Moo role which defines a standard API for a class which can
be used to encode data. Any class which implements this role is
guaranteed to have a C<encode> method. Although not required,
typically those classes will appear in the L<Xenon::Encoding>
namespace.

=head1 ATTRIBUTES

This role does not add any attributes to the consuming class.

=head1 SUBROUTINES/METHODS

=over

=item encode

This role requires that the consuming class implements a C<encode>
method. The C<encode> method must take an encoded string as an
argument and return the encoded string.

=item new_from_json

This role also imports the L<Xenon::Role::ConfigFromJSON> which adds a
C<new_from_json> method. See the documentation for that role for more
details.

=back

=head1 DEPENDENCIES

This module is powered by L<Moo>. It also requires the
L<Xenon::Role::ConfigFromJSON> role.

=head1 SEE ALSO

L<Xenon>, L<Xenon::Role::ContentEncoder>

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

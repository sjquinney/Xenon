package Xenon::Encoding::Base64; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use MIME::Base64 ();

use Moo;

with 'Xenon::Role::ContentDecoder', 'Xenon::Role::ContentEncoder';

use namespace::clean;

# As well as the standard Base64 encoding style this handles encoding
# and decoding the slightly bizarre LCFG-style where each line of
# contents is encoded separately and then the lines are joined
# together with a *literal* \n string (NOT a newline). An empty string
# between two literal \n strings will generate a newline.

sub encode {
    my ( $self, $input, $options ) = @_;

    $options //= {};
    my $style = $options->{style} // 'standard';

    my $output;
    if ( $style eq 'lcfg' ) {
        $output = q{};
        while ( $input =~ m/^(.*?)$/mg ) {
            my $line = $1 . "\n"; # replace the newline lost in the regexp
            $output .= MIME::Base64::encode_base64($line,"\\n");
        }
        $output .= "\n";
    } else {
        $output = MIME::Base64::encode_base64($input);
    }

    return $output;
}

sub decode {
    my ( $self, $encoded ) = @_;

    my $decoded = q{};
    for my $line (split /\\n/, $encoded) {
        my $decoded_line;
        if ( length $line > 0 ) {
            $decoded_line = MIME::Base64::decode_base64($line);
        } else {
            $decoded_line = "\n";
        }
        $decoded .= $decoded_line;
    }

    return $decoded;
}

1;
__END__

=head1 NAME

Xenon::Encoding::Base64 - Base64 encoder and decoder

=head1 VERSION

This documentation refers to Xenon::Encoding::Base64 version 1.0.0

=head1 SYNOPSIS

  use Xenon::Encoding::Base64;

  my $base64 = Xenon::Encoding::Base64->new();

  my $encoded = $base64->encode("hello world");

  my $decoded = $base64->decode($encoded);

  # LCFG-style line-by-line encoding with literal '\n' separator

  my $lcfg_encoded = $base64->encode( "hello world",
                                      { style => "lcfg" } );

=head1 DESCRIPTION

This class implements the L<Xenon::Role::ContentEncoder> and
L<Xenon::Role::ContentDecoder> roles for the MIME Base64 encoding type
(RFC 2045). As well as the standard data representations it supports
the LCFG encoding style.

=head1 ATTRIBUTES

This class does not have any attributes.

=head1 SUBROUTINES/METHODS

The following methods are available:

=over

=item new()

This can be used to create a new L<Xenon::Encoding::Base64> instance.

=item new_from_json($json)

This can be used to create a new L<Xenon::Encoding::Base64> instance
with the option to specify attributes as a JSON file or string. See
the documentation for the L<Xenon::Role::ConfigFromJSON> role for more
details.

=item decode($encoded)

This method will return the decoded version of the specified
Base64-encoded string.

As well as the standard Base64 encoding style it supports decoding of
the LCFG-style encoding where each line of a file is encoded
separately and then joined with a literal C<\n> separator (B<NOT> a
newline character).

=item encode( $input, $options )

This method will return the Base64-encoded version of the specified
string.

As well as the standard Base64 encoding style it supports encoding
data in the LCFG-style where each line of a file is encoded separately
and then joined with a literal C<\n> separator (B<NOT> a newline
character). This style can be enabled by passing an a reference to a
hash with the value of the C<style> key set to C<lcfg>, i.e.

  my $encoded = $base64->encode( "hello world",
                                 { style => "lcfg" } );

=back

=head1 DEPENDENCIES

This module is powered by L<Moo>. It implements the
L<Xenon::Role::ContentDecoder> and L<Xenon::Role::ContentEncoder>
roles. It requires the L<MIME::Base64> module to do the encoding and
decoding. It also implements the L<Xenon::Role::ConfigFromJSON> role,
to use that role the L<JSON> module must be available.

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

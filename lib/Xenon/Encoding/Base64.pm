package Xenon::Encoding::Base64; # -*- perl -*-
use strict;
use warnings;

use v5.10;

use Moo;
use namespace::clean;

with 'Xenon::Role::ContentDecoder';

sub decode {
    my ( $self, $encoded ) = @_;

    require MIME::Base64;

    # As well as the standard Base64 encoding style this handles the
    # slightly bizarre LCFG-style where each line of contents is
    # encoded separately and then the lines are joined together with a
    # *literal* \n string (NOT a newline). An empty string between two
    # literal \n strings will generate a newline.

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

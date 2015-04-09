package Xenon::Encoding::Base64; # -*- perl -*-
use strict;
use warnings;

our $VERSION = v1.0.0;

use v5.10;

use Moo;
use namespace::clean;

with 'Xenon::Role::ContentDecoder', 'Xenon::Role::ContentEncoder';

# As well as the standard Base64 encoding style this handles encoding
# and decoding the slightly bizarre LCFG-style where each line of
# contents is encoded separately and then the lines are joined
# together with a *literal* \n string (NOT a newline). An empty string
# between two literal \n strings will generate a newline.

sub encode {
    my ( $self, $input, $options ) = @_;

    $options //= {};
    my $style = $options->{style} // 'standard';

    require MIME::Base64;

    my $output;
    if ( $style eq 'lcfg' ) {
        $output = q{};
        while ( $input =~ m/^(.*?)$/mg ) {
            my $line = $1 . "\n";
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

    require MIME::Base64;

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

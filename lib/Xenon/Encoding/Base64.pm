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

    my $decoded = MIME::Base64::decode_base64($encoded);

    return $decoded;
}

1;

package Xenon::Env::Vars; # -*- perl -*-
use strict;
use warnings;

use v5.10;

our $VERSION = '@LCFG_VERSION@';

use Moo;
use Types::Standard qw(HashRef);

with 'Xenon::Role::Env';

use namespace::clean;

has 'vars' => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

sub run {
    my ($self) = @_;

    my %vars = %{ $self->vars };
    for my $key ( keys %vars ) {
        my $value = $vars{$key};

        $self->logger->debug("Setting env var '$key' to '$value'");

        $ENV{$key} = $value;
    }

    return;
}

1;
__END__

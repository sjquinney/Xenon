package Xenon::Env::Vars; # -*- perl -*-
use strict;
use warnings;

use v5.10;

our $VERSION = '@LCFG_VERSION@';

use Moo;
use Types::Standard qw(Bool HashRef);

with 'Xenon::Role::EnvHandler';

use namespace::clean;

has 'clear' => (
    is      => 'ro',
    isa     => Bool,
    default => sub { 0 },
);

has 'vars' => (
    is      => 'ro',
    isa     => HashRef,
    default => sub { {} },
);

sub run {
    my ($self) = @_;

    if ( $self->clear ) {
        $self->logger->debug('Clearing all environment variables');
        %ENV = ();
    }

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
